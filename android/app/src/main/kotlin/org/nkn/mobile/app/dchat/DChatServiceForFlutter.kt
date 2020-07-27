/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.dchat

import android.app.*
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import hobby.wei.c.core.AbsMsgrService
import nkn.Account
import nkn.ClientConfig
import nkn.MultiClient
import nkn.Nkn
import org.nkn.mobile.app.App
import org.nkn.mobile.app.BuildConfig
import org.nkn.mobile.app.MainActivity
import org.nkn.mobile.app.R
import org.nkn.mobile.app.abs.StartMe
import java.util.concurrent.TimeUnit

/**
 * @author Wei.Chou
 * @version 1.0, 25/03/2020,
 *          1.1, 27/07/2020, for flutter.
 */
class DChatServiceForFlutter : AbsMsgrService(), Const {
    override val needKeepWake = true

    // Note: When changing this property to `false`, the permission should be deleted at the same time.
    // <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    override val ignoringBatteryOptimization = false //BuildConfig.FLAVOR != "googleplay"

    @Volatile
    private var foreground = false
    private var isScreenOn = false

    private val broadcastReceiver by lazy {
        return@lazy object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON -> {
                        isScreenOn = true
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        isScreenOn = false
                        App.handler().removeCallbacks(serviceForceStartWorkRun)
                        App.handler().postDelayed(serviceForceStartWorkRun, TimeUnit.MINUTES.toMillis(3))
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        isScreenOn = true
                    }
                    else -> {
                    }
                }
            }
        }
    }

    private val serviceForceStartWorkRun by lazy {
        Runnable {
            if (!isScreenOn && foreground) {
                Log.w(TAG, "serviceForceStartWorkRun | ensureFlutterPluginInited")
                ensureFlutterPluginInited()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter()
        filter.addAction(Intent.ACTION_SCREEN_OFF)
        filter.addAction(Intent.ACTION_SCREEN_ON)
        filter.addAction(Intent.ACTION_USER_PRESENT)

        registerReceiver(broadcastReceiver, filter)
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        notifyMgr.cancel(notificationID)
        ensureFlutterPluginDestroyed()

        unregisterReceiver(broadcastReceiver)
        super.onDestroy()
    }

    override fun onStartWork(callCount: Int) {}

    override fun onStopWork(callCount: Int): Int {
        ensureFlutterPluginDestroyed()
        return 0 // can stop.
    }

    // If main process been killed, and not finished normally, this function may return `true`.
    // in other words, this does not work well.
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

    @Volatile
    private var flutterPlugin: MessagingServiceFlutterPlugin? = null

    private fun ensureFlutterPluginInited() {
        // java.lang.IllegalStateException: ensureInitializationComplete must be called on the main thread
        //        at io.flutter.embedding.engine.loader.FlutterLoader.ensureInitializationComplete(FlutterLoader.java:150)
        //        at io.flutter.embedding.engine.FlutterEngine.<init>(FlutterEngine.java:184)
        App.runOnMainThread {
            flutterPlugin ?: synchronized(this) {
                flutterPlugin ?: also {
                    if (!foreground) {
                        Log.e(TAG, "call init flutter plugin, but current is 'NOT' on foreground.")
                        return@also
                    }
                    val plugin = MessagingServiceFlutterPlugin(this) {
                        Log.i(TAG, "ensureFlutterPluginInited | initialized")
                        flutterPlugin?.onNativeReady()
                    }
                    flutterPlugin = plugin
                }
            }
        }
    }

    private fun ensureFlutterPluginDestroyed() {
        if (foreground) {
            Log.w(TAG, "call destroy flutter plugin, but current is on foreground.")
            return
        }
        val plugin = flutterPlugin
        flutterPlugin = null
        plugin?.destroy()
    }

    override fun confirmIfCommandConsumed(intent: Intent?): Boolean {
        return if (intent?.getBooleanExtra(CMD_EXTRA_FORCE_START_WORK, false) == true) {
            Log.d(TAG, "--->>> CMD_EXTRA_FORCE_START_WORK --->>>")
            ensureFlutterPluginInited()
            true
        } else if (intent?.getBooleanExtra(CMD_EXTRA_FORCE_STOP_WORK, false) == true) {
            Log.d(TAG, "<<<--- CMD_EXTRA_FORCE_STOP_WORK <<<---")
            ensureFlutterPluginDestroyed()
            true
        }else super.confirmIfCommandConsumed(intent)
    }

    override fun onStartForeground() {
        Log.i(TAG, "onStartForeground")
        // preload channels, fix crash.
        notifyMgr.importance
        // fix bug of `Context.startForegroundService, but not Service not call startForeground()`.
        startForeground(notificationID, buildForegroundNotification())
        foreground = true
    }

    override fun onStopForeground() {
        foreground = false
        super.onStopForeground()
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

        fun forceStartWork(ctx: Context) {
            val intent = Intent(ctx, DChatServiceForFlutter::class.java)
            intent.putExtra(CMD_EXTRA_FORCE_START_WORK, true)
            ctx.startService(intent)
        }

        fun forceStopWork(ctx: Context) {
            val intent = Intent(ctx, DChatServiceForFlutter::class.java)
            intent.putExtra(CMD_EXTRA_FORCE_STOP_WORK, true)
            ctx.startService(intent)
        }
    }
}

interface Const : StartMe.Const {
    override val MSG_REPLY_TO get() = 999999999
    override val MSG_UN_REPLY get() = 888888888
    override val CMD_EXTRA_STOP_SERVICE get() = App.withPackageNamePrefix("CMD_EXTRA_STOP_SERVICE")
    override val CMD_EXTRA_START_FOREGROUND get() = App.withPackageNamePrefix("CMD_EXTRA_START_FOREGROUND")
    override val CMD_EXTRA_STOP_FOREGROUND get() = App.withPackageNamePrefix("CMD_EXTRA_STOP_FOREGROUND")
    val CMD_EXTRA_FORCE_START_WORK get() = App.withPackageNamePrefix("CMD_EXTRA_FORCE_START_WORK")
    val CMD_EXTRA_FORCE_STOP_WORK get() = App.withPackageNamePrefix("CMD_EXTRA_FORCE_STOP_WORK")
}
