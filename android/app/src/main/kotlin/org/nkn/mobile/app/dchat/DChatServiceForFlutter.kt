/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.dchat

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import hobby.wei.c.core.AbsMsgrService
import hobby.wei.c.tool.RetryByHandler.DelayerOf
import nkn.Account
import nkn.ClientConfig
import nkn.MultiClient
import nkn.Nkn
import org.nkn.mobile.app.App
import org.nkn.mobile.app.R
import org.nkn.mobile.app.abs.StartMe
import org.nkn.mobile.app.MainActivity
import org.nkn.mobile.app.util.Bytes2String.toHex
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix
import java.util.concurrent.TimeUnit

/**
 * @author Wei.Chou
 * @version 1.0, 25/03/2020
 */
class DChatServiceForFlutter : AbsMsgrService(), Msgs.Resp, Const {
    override val needKeepWake = true

    // Note: When changing this property to `false`, the permission should be deleted at the same time.
    // <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    override val ignoringBatteryOptimization = false //BuildConfig.FLAVOR != "googleplay"

    @Volatile
    private var foreground = false

    private val msgSendHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgSendHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        Handler(thread.looper)
    }
    private val msgReceiveHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgReceiveHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        Handler(thread.looper)
    }

    private val msgSendDelayer by lazy { DelayerOf(msgSendHandler) }

    @Volatile
    private var clientConnected = false

    @Volatile
    private var accountPubkeyHex: String? = null

    @Volatile
    private var accountCache: Account? = null

    @Volatile
    private var messagingClient: MultiClient? = null
    private fun genClient(account: Account): MultiClient? {
        return messagingClient ?: synchronized(this) {
            try {
                val conf = ClientConfig()
                //conf.seedRPCServerAddr =
                //  Nkn.newStringArrayFromString("https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
                messagingClient = Nkn.newMultiClient(account, null, 3, true, conf)
                messagingClient!!
            } catch (e: Exception) {
                try {
                    messagingClient?.close()
                } catch (ex: Exception) {
                }
                messagingClient = null
                Log.e(TAG, "genClient(): MultiClient?", e)
                null
            }
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        destroyAccountCorrelation()
        msgSendHandler.post {
            msgSendHandler.looper.quitSafely()
        }
        msgReceiveHandler.post {
            msgReceiveHandler.looper.quitSafely()
        }
        notifyMgr.cancel(notificationID)
        flutterPlugin?.destroy()
        super.onDestroy()
    }

    private fun destroyAccountCorrelation() {
        Log.d(TAG, "destroyAccountCorrelation")
        try {
            messagingClient?.close()
        } catch (ex: Exception) {
        }
        messagingClient = null
        accountPubkeyHex = null
        changeConnectionState(false)
    }

    override fun onStartWork(callCount: Int) {
        Log.i(TAG, "onStartWork($callCount)")
        considerActivityIsRunning()
        clientHandler.post {
            wakeup()
        }
    }

    // not main thread(clientHandler thread)
    fun wakeup() {
        Log.i(TAG, "wakeup")
        // queue with `retryForceful()`
        msgSendHandler.post {
            Log.i(TAG, "wakeup ->")
            if (messagingClient == null) {
                // do nothing...
//                sendMsg2Client(buildMsg4ObtainAccount())
            } else {
                wakeupInner()
            }
        }
    }

    private fun wakeupInner() {
        doConnect()
        receiveMessages()
    }

    @Volatile
    private var isActivityRunning: Boolean = true
    private fun considerActivityIsRunning(stopCheckLoop: Boolean = false): Boolean {
        if (stopCheckLoop) {
            msgSendHandler.removeCallbacks(checkIfMainActyActiveRun)
        } else {
            ensureWakeupWhenActivityNotRunning()
        }
        checkIfMainActyActiveRun.run()
        return isActivityRunning
    }

    private fun ensureWakeupWhenActivityNotRunning() {
        Log.d(TAG, "ensureWakeupWhenActivityNotRunning".withAndroidPrefix())
        msgSendHandler.removeCallbacks(checkIfMainActyActiveRun)
        msgSendHandler.postDelayed(checkIfMainActyActiveRun, TimeUnit.MINUTES.toMillis(3))
    }

    private val checkIfMainActyActiveRun: Runnable by lazy {
        Runnable {
            Log.i(TAG, "checkIfMainActyActiveRun".withAndroidPrefix())
            isActivityRunning = isMainActivityActive()
            Log.e(TAG, "isActivityRunning: $isActivityRunning".withAndroidPrefix())
            if (isActivityRunning) {
                destroyAccountCorrelation()
                Log.i(TAG, "accountCache: $accountCache".withAndroidPrefix())
            } else {
                Log.i(TAG, "accountCache: $accountCache".withAndroidPrefix())
                onAccountGot(accountCache)
            }
            ensureWakeupWhenActivityNotRunning()
        }
    }

    private fun isMainActivityActive(): Boolean {
        val actyManager = getSystemService(ActivityManager::class.java)
        val i = packageName.lastIndexOf(':')
        val mainPkgName = if (i <= 0) packageName else packageName.substring(0, i)
        Log.w(TAG, "isMainActivityActive | $mainPkgName, $packageName")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val tasks = actyManager.appTasks
                for (task in tasks) {
                    Log.i(TAG, "isMainActivityActive | VERSION_CODES.Q | ${task.taskInfo.baseActivity?.className
                    }, numActy: ${task.taskInfo.numActivities}")
                    if (task.taskInfo.isRunning) {
                        return true
                    }
                }
            } else {
                val tasks = actyManager.getRunningTasks(Int.MAX_VALUE)
                for (task in tasks) {
                    Log.i(TAG, "isMainActivityActive | ${task.baseActivity?.className}, numActy: ${task.numActivities}")
                    if (mainPkgName.equals(task.baseActivity?.packageName, ignoreCase = true)) {
                        return true
                    }
                }
            }
            return false
        } catch (e: SecurityException) {
            Log.w(TAG, "Lack permission 'android.permission.GET_TASKS'")
            throw e
        }
    }

    // not main thread(clientHandler thread)
    fun onAccountGot(account: Account?) {
        Log.i(TAG, "onAccountGot")
        accountCache = account
        accountPubkeyHex = ensureSameAccount(account)
        account?.let {
            retryForceful(3 * 1000, increase = 2 * 1000) {
                // Different threads, there is a reset situation.
                if (account == null || isActivityRunning) {
                    true
                } else {
                    if (genClient(account) != null) {
                        accountCache = account
                        wakeupInner()
                        true
                    } else false
                }
            }
        }
    }

    // not main thread(clientHandler thread)
    private fun ensureSameAccount(account: Account?): String? {
        return if (account == null) {
            destroyAccountCorrelation()
            null
        } else {
            val pubkey = account.pubKey().toHex()
            Log.i(TAG, "ensureSameAccount | new: $pubkey")
            if (accountPubkeyHex != pubkey) {
                Log.i(TAG, "ensureSameAccount | old: ${accountPubkeyHex ?: "null"}, new: $pubkey")
                destroyAccountCorrelation()
            }
            pubkey
        }
    }

    // not main thread(clientHandler thread)
    fun feedbackConnectionState() {
        sendMsg2Client(buildMsg4ConnectionState(clientConnected))
    }

    private fun changeConnectionState(bool: Boolean) {
        if (clientConnected != bool) {
            clientConnected = bool
            feedbackConnectionState()
        }
    }

    // There is no need to deal with the problem of network disconnection, the
    // `MultiClient` underlying layer will handle it.
    // not main thread(clientHandler thread)
    private fun doConnect() {
        Log.i(TAG, "doConnect")
        msgSendHandler.post {
            retryForceful(6 * 1000, increase = 6 * 1000, custom = msgSendDelayer) {
                Log.d(TAG, "doConnect | retryForceful")
                if (isActivityRunning) return@retryForceful true
                if (!clientConnected) {
                    Log.d(TAG, "doConnect | retryForceful | clientConnected: false")
                    val msgClient = messagingClient
                    msgClient?.let { client ->
                        try {
                            Log.w(TAG, "doConnect | retryForceful | client.onConnect.next() -->")
                            // must execute exactly once
                            val node = client.onConnect.next()
                            Log.i(
                                    TAG, "client.onConnect() Done | " +
                                    "node.id: ${node.id}, " +
                                    "node.addr: ${node.addr}, " +
                                    "node.pubkey:${node.pubKey}, " +
                                    "node.rpcAddr:${node.rpcAddr}"
                            )
                            changeConnectionState(true)
                            receiveMessages()
                        } catch (e: Exception) {
                            Log.e(TAG, "doConnect", e)
                        }
                    }
                }
                clientConnected
            }
        }
    }

    private fun receiveMessages() {
        Log.i(TAG, "receiveMessages")
        msgReceiveHandler.removeCallbacks(receiveMessagesRun)
        if (isActivityRunning) {
            Log.i(TAG, "receiveMessages | isActivityRunning: $isActivityRunning".withAndroidPrefix())
            // nothing...
        } else {
            if (ensureFlutterPluginInited()) {
                msgReceiveHandler.post(receiveMessagesRun)
            }
        }
    }

    private val receiveMessagesRun: Runnable by lazy {
        Runnable {
            Log.i(TAG, "receiveMessagesRun")
            try {
                val myChatId = accountPubkeyHex
                val msgClient = messagingClient
                msgClient?.let { client ->
                    Log.i(TAG, "receiveMessages | wait for next -->")
                    val msg = client.onMessage.next()
                    handleReceivedMessages(msg, myChatId!!)
                    receiveMessages()
                }
            } catch (e: Exception) {
                Log.e(TAG, "receiveMessages", e)
                // clientConnected = false
                // doConnect()
                msgReceiveHandler.postDelayed({ receiveMessages() }, 5000)
            }
        }
    }

    private fun handleReceivedMessages(msgNkn: nkn.Message, myChatId: String) {
        val json = String(msgNkn.data, Charsets.UTF_8)
        Log.i(TAG, "receiveMessages | from: ${msgNkn.src}, json: ${if (json.length > 100) json.substring(0, 100) else json}")

        App.handler().post {
            flutterPlugin!!.onMessage(msgNkn, accountPubkeyHex!!, json)
        }
    }

    @Volatile
    private var flutterPlugin: MessagingServiceFlutterPlugin? = null

    @Volatile
    private var flutterPluginInited: Boolean = false

    private fun ensureFlutterPluginInited(): Boolean {
        flutterPlugin ?: synchronized(this) {
            flutterPlugin ?: also {
                val plugin = MessagingServiceFlutterPlugin(this) {
                    Log.i(TAG, "ensureFlutterPluginInited | flutterPluginInited")
                    flutterPluginInited = true
                    receiveMessages()
                }
                flutterPlugin = plugin
            }
        }
        return flutterPluginInited
    }

    override fun onStopWork(callCount: Int): Int {
        return 0 // TimeUnit.MINUTES.toMillis(10).toInt()
    }

    override fun onStartForeground() {
        Log.i(TAG, "onStartForeground")
        if (accountCache == null) {
            stopSelf()
        } else {
            considerActivityIsRunning()
        }
        // preload channels, fix crash.
        notifyMgr.importance
        // fix bug of `Context.startForegroundService, but not Service not call startForeground()`.
        startForeground(notificationID, buildForegroundNotification())
        foreground = true
    }

    override fun onStopForeground() {
        considerActivityIsRunning(true)
        foreground = false
        super.onStopForeground()
    }

    override fun handleClientMsg(msg: Message, handler: Handler) {
        if (!handleClientMsg(msg, handler, this)) {
            super<AbsMsgrService>.handleClientMsg(msg, handler)
        }
    }


    private val notificationID = 88888888
    private val channelIDForeground = App.withPackageNamePrefix("d_chat_background_service")
    private val notifyMgr by lazy {
        val mgr = NotificationManagerCompat.from(this)
        mgr.createNotificationChannels(
                arrayListOf(
//                buildChannel(Vibration),
                        buildForegroundChannel()
                )
        )
        mgr
    }

    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, channelIDForeground)
                .setSmallIcon(R.drawable.icon_logo)
                .setContentTitle(getString(R.string.n_mobile))
                .setContentIntent(buildContentIntent())
                .setContentText(getString(R.string.d_chat_background_connection))
                .setAutoCancel(false)
                .setShowWhen(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                // Must be set here, only in the channel, does not work. But the phone must be set to slide unlock at least.
                .setVisibility(NotificationCompat.VISIBILITY_SECRET)
                .build()
    }

    private fun buildForegroundChannel(): NotificationChannel? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                    channelIDForeground,
                    getString(R.string.d_chat_background_connection),
                    NotificationManager.IMPORTANCE_NONE
            )
            channel.setShowBadge(false)
            channel.lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET
            channel
        } else null
    }

    private fun buildContentIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
        intent.action = Intent.ACTION_MAIN
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        return PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
    }

    override var mWakeLock: PowerManager.WakeLock? = null

    companion object Starter : StartMe.MsgrSrvce, Const {
        fun start(ctx: Context) = start(ctx, DChatServiceForFlutter::class.java)

        fun stop(ctx: Context): Unit = stop(ctx, DChatServiceForFlutter::class.java)

        fun startFg(ctx: Context): Unit = startFg(ctx, DChatServiceForFlutter::class.java)

        fun stopFg(ctx: Context): Unit = stopFg(ctx, DChatServiceForFlutter::class.java)

        fun bind(ctx: Context, conn: ServiceConnection): Unit = bind(ctx, conn, DChatServiceForFlutter::class.java)
    }
}

interface Const : StartMe.Const {
    override val MSG_REPLY_TO: Int
        get() = 999999999
    override val MSG_UN_REPLY: Int
        get() = 888888888
    override val CMD_EXTRA_STOP_SERVICE: String
        get() = App.withPackageNamePrefix("CMD_EXTRA_STOP_SERVICE")
    override val CMD_EXTRA_START_FOREGROUND: String
        get() = App.withPackageNamePrefix("CMD_EXTRA_START_FOREGROUND")
    override val CMD_EXTRA_STOP_FOREGROUND: String
        get() = App.withPackageNamePrefix("CMD_EXTRA_STOP_FOREGROUND")
}
