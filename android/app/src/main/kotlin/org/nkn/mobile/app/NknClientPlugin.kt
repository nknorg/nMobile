package org.nkn.mobile.app

import android.content.Context
import android.os.HandlerThread
import android.os.Process
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import nkn.*
import org.json.JSONObject
import org.nkn.mobile.app.util.Bytes2String.toHex
import service.GooglePushService
import java.security.KeyStore
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

class NknClientPlugin(private val acty: MainActivity?, flutterEngine: FlutterEngine) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val N_MOBILE_SDK_CLIENT = "org.nkn.sdk/client"
        private const val N_MOBILE_SDK_CLIENT_EVENT = "org.nkn.sdk/client/event"
    }

    init {
        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_CLIENT).setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_CLIENT_EVENT).setStreamHandler(this)
    }

    private lateinit var clientEventSink: EventChannel.EventSink

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        clientEventSink = events
    }

    override fun onCancel(arguments: Any?) {
    }

    private val msgSendHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgSendHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val subscribersHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".subscribersHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val msgReceiveHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgReceiveHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createClient" -> {
                createClient(call, result)
            }
            "connect" -> {
                connect()
                result.success(null)
            }
            "startReceiveMessages" -> {
                receiveMessages()
                result.success(null)
            }
            "isConnected" -> {
                isConnected(call, result)
            }
            "disConnect" -> {
                disConnect(call, result, true)
            }
            "sendText" -> {
                sendText(call, result)
            }
            "publishText" -> {
                publishText(call, result)
            }
            "subscribe" -> {
                subscribe(call, result)
            }
            "unsubscribe" -> {
                unsubscribe(call, result)
            }
            "getSubscribersCount" -> {
                getSubscribersCount(call, result)
            }
            "getSubscribers" -> {
                getSubscribers(call, result)
            }
            "getSubscription" -> {
                getSubscription(call, result)
            }
            "getBlockHeight" -> {
                getBlockHeight(call, result)
            }
            "fetchDeviceToken" -> {
                getDeviceToken(call, result)
            }
            "checkGoogleService" -> {
                onCheckGooglePlayServices(call, result)
            }
            "fetchDebugInfo" -> {
                fetchDebugInfo(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getDeviceToken(call: MethodCall, result: MethodChannel.Result){
        val _id = call.argument<String>("_id")!!
        result.success(null)
        msgSendHandler.post {
            try {
                val _id = call.argument<String>("_id")!!
                val sharedPreferences = App.get().getSharedPreferences("fcmToken", Context.MODE_PRIVATE);
                val deviceToken = sharedPreferences.getString("token", "");
                Log.e("getDeviceToken", "getDeviceToken | e:" + deviceToken.toString())
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "fetch_device_token",
                        "device_token" to deviceToken.toString()
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getDeviceTokenE", "getSubscription | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    /**
     * 检查 Google Play 服务
     */
    private fun onCheckGooglePlayServices(call: MethodCall, result: MethodChannel.Result) {
        // 验证是否已在此设备上安装并启用Google Play服务，以及此设备上安装的旧版本是否为此客户端所需的版本
        val code = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(acty)
        var googleServiceOn:Boolean = true;
        if (code == ConnectionResult.SUCCESS) {
            // 支持Google服务
            Log.e("GoogleC","GoogleService Available")
        } else {
            googleServiceOn = false;
            Log.e("GoogleC","GoogleService Unavailable")
        }
        val _id = call.argument<String>("_id")!!
        result.success(null)

        msgSendHandler.post {
            try {
                val _id = call.argument<String>("_id")!!
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "google_service_on",
                        "googleServiceOn" to googleServiceOn
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("serviceCheck", "onCheckGooglePlayServices | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun createClient(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val identifier = call.argument<String>("identifier")
        val seedBytes = call.argument<ByteArray>("seedBytes")!!
        val clientUrl = call.argument<String>("clientUrl")
        result.success(null)

        msgSendHandler.post {
            try {
                val account = Nkn.newAccount(seedBytes)
                accountPubkeyHex = ensureSameAccount(account)
                val client = genClientIfNotExists(account, identifier, clientUrl)
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "createClient",
                        "success" to if (client == null) 0 else 1
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
                if (client != null) acty?.onClientCreated()
            } catch (e: Exception) {
                Log.e("createClient", "createClient | e:", e)
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "createClient",
                        "success" to 0
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            }
        }
    }

    private fun connect() {
        msgSendHandler.post {
            try {
                if (isConnected) return@post
                val client = multiClient
                val node = client!!.onConnect.next()
                isConnected = true
                val data = hashMapOf(
                        "event" to "onConnect",
                        "node" to hashMapOf("address" to node.addr, "publicKey" to node.pubKey),
                        "client" to hashMapOf("address" to client.address())
                )
                App.runOnMainThread {
                    clientEventSink.success(data)
                }
            } catch (e: Exception) {
                Log.e("connectE", "connect | e:", e)
            }
        }
    }

    @Deprecated(message = "No longer needed.")
    private fun isConnected(call: MethodCall, result: MethodChannel.Result) {
        if (multiClient != null) {
            result.success(isConnected)
        } else {
            result.success(false)
        }
    }

    private fun disConnect(call: MethodCall?, result: MethodChannel.Result?, callFromDart: Boolean) {
        result?.success(null)
        val clientAddr = multiClient?.address()
        val isConn = isConnected
        closeClientIfExists()
        if (!callFromDart && isConn) {
            App.runOnMainThread {
                val data = hashMapOf(
                        "event" to "onDisConnect",
                        "client" to hashMapOf("address" to clientAddr)
                )
                clientEventSink.success(data)
            }
        }
    }

    private fun receiveMessages() {
        msgReceiveHandler.removeCallbacks(receiveMessagesRun)
        msgReceiveHandler.post(receiveMessagesRun)
    }

    private val receiveMessagesRun: Runnable by lazy {
        Runnable {
            try {
                val client = multiClient
                client?.let { client ->
                    val msg = client.onMessage.next()
                    if (msg != null) {
                        val data = hashMapOf(
                                "event" to "onMessage",
                                "client" to hashMapOf("address" to client.address()),
                                "data" to hashMapOf(
                                        "src" to msg.src,
                                        "data" to String(msg.data, Charsets.UTF_8),
                                        "type" to msg.type,
                                        "encrypted" to msg.encrypted,
                                        "pid" to msg.messageID
                                )
                        )
                        App.runOnMainThread {
                            clientEventSink.success(data)
                        }
                    } else {
                        // nothing...
                    }
                    receiveMessages()
                }
            } catch (e: Exception) {
                Log.e("receiveMessagesRun", "receiveMessages | e:", e)
                msgReceiveHandler.postDelayed({ receiveMessages() }, 5000)
            }
        }
    }

    private fun sendText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val dests = call.argument<ArrayList<String>>("dests")!!
        val data = call.argument<String>("data")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds")!!
        result.success(null)

        val dataObj = JSONObject(data)
        if (dataObj.optString("deviceToken").isNotEmpty()){
            val deviceToken = dataObj["deviceToken"].toString()
            val pushContent = dataObj["pushContent"].toString()
            Log.e("xxxxxxxxxx", "xxxxxxxxxx | e__"+pushContent)
            val code = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(acty)
            if (code == ConnectionResult.SUCCESS && pushContent?.length > 0){
                val service = GooglePushService()
                service.sendMessageToFireBase(deviceToken, pushContent)
            }
        }

        var nknDests: StringArray? = null
        for (d in dests) {
            if (nknDests == null) {
                nknDests = Nkn.newStringArrayFromString(d)
            } else {
                nknDests.append(d)
            }
        }
        if (nknDests == null) {
            App.runOnMainThread {
                clientEventSink.error(_id, "dests null", null)
            }
            return
        }

        val config = MessageConfig()
        config.maxHoldingSeconds = if (maxHoldingSeconds < 0) Int.MAX_VALUE else maxHoldingSeconds
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.noReply = true
        msgSendHandler.post {
            try {
                multiClient!!.sendText(nknDests, data, config)
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "send",
                        "pid" to config.messageID
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("sendTextE", "sendText | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun publishText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val topicHash = call.argument<String>("topicHash")!!
        val data = call.argument<String>("data")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds")!!
        result.success(null)

        val config = MessageConfig()
        config.maxHoldingSeconds = if (maxHoldingSeconds < 0) Int.MAX_VALUE else maxHoldingSeconds
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.noReply = true
        msgSendHandler.post {
            try {
                multiClient!!.publishText(topicHash, data, config)
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "send",
                        "pid" to config.messageID
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("publishTextE", "publishText | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun subscribe(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val identifier = call.argument<String>("identifier") ?: ""
        val topicHash = call.argument<String>("topicHash")!!
        val duration = call.argument<Int>("duration")!!
        val meta = call.argument<String>("meta")
        val fee = call.argument<String>("fee") ?: "0"
        result.success(null)

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee

        subscribersHandler.post {
            try {
                val hash = multiClient!!.subscribe(identifier, topicHash, duration.toLong(), meta, transactionConfig)
                val resp = hashMapOf(
                        "_id" to _id,
                        "result" to hash
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("subscribeE", "subscribe | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun unsubscribe(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val identifier = call.argument<String>("identifier") ?: ""
        val topicHash = call.argument<String>("topicHash")!!
        val fee = call.argument<String>("fee") ?: "0"
        result.success(null)

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee

        subscribersHandler.post {
            try {
                val hash = multiClient!!.unsubscribe(identifier, topicHash, transactionConfig)
                val resp = hashMapOf(
                        "_id" to _id,
                        "result" to hash
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("unsubscribe", "unsubscribe | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun getSubscribers(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val topicHash = call.argument<String>("topicHash")!!
        val offset = call.argument<Int>("offset") ?: 0
        val limit = call.argument<Int>("limit") ?: 0
        val meta = call.argument<Boolean>("meta") ?: true
        val txPool = call.argument<Boolean>("txPool") ?: true
        result.success(null)

        subscribersHandler.post {
            try {
                val subscribers = multiClient!!.getSubscribers(topicHash, offset.toLong(), limit.toLong(), meta, txPool)

                val map = HashMap<String, String>()
                map.put("_id", _id!!)

                subscribers.subscribersInTxPool.range { chatId, value ->
                    val meta = value?.trim() ?: ""
                    map[chatId] = meta
                    true
                }
                subscribers.subscribers.range { chatId, value ->
                    val meta = value?.trim() ?: ""
                    map.put(chatId, meta)
                    true
                }
                App.runOnMainThread {
                    clientEventSink.success(map)
                }
            } catch (e: Exception) {
                Log.e("getSubscribers", "getSubscribers | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun getSubscription(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val topicHash = call.argument<String>("topicHash")!!
        val subscriber = call.argument<String>("subscriber")!!
        result.success(null)

        subscribersHandler.post {
            try {
                val subscription = multiClient!!.getSubscription(topicHash, subscriber)
                val resp = hashMapOf(
                        "_id" to _id,
                        "meta" to subscription.meta,
                        "expiresAt" to subscription.expiresAt
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getSubscriptionE", "getSubscription | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun getBlockHeight(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        result.success(null)

        subscribersHandler.post {
            try {
                val height = multiClient!!.height;
                val resp = hashMapOf(
                        "_id" to _id,
                        "height" to height
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getBlockHeightE", "getSubscription | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun fetchDebugInfo(call: MethodCall, result: MethodChannel.Result){
        Log.e("222:","HereHere")
        val ks: KeyStore = KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        val aliases: Enumeration<String> = ks.aliases()

        var keyStoreAliases:String = ""
        while (aliases.hasMoreElements()){
            val alias:String = aliases.nextElement();
            keyStoreAliases = keyStoreAliases+alias;
        }
        Log.e("111:"+keyStoreAliases,"keyStoreAliases:"+keyStoreAliases)

        val _id = call.argument<String>("_id")!!
        result.success(null)

        msgSendHandler.post {
            try {
                val _id = call.argument<String>("_id")!!
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "fetch_debug_info",
                        "debugInfo" to keyStoreAliases
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("fetchDebugInfoE", "fetchDebugInfoE | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun getSubscribersCount(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val topicHash = call.argument<String>("topicHash")!!
        result.success(null)

        subscribersHandler.post {
            try {
                val count = multiClient!!.getSubscribersCount(topicHash)
                val resp = hashMapOf(
                        "_id" to _id,
                        "result" to count
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getSubscribersCount", "getSubscribersCount | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, e.message, null)
                }
            }
        }
    }

    private fun ensureSameAccount(account: Account?): String? {
        return if (account == null) {
            closeClientIfExists()
            null
        } else {
            val pubkey = account.pubKey().toHex()
            Log.i("ensureSameAccount", "ensureSameAccount | new: $pubkey")
            if (accountPubkeyHex != pubkey) {
                Log.i("ensureSameAccountE", "ensureSameAccount | old: ${accountPubkeyHex ?: "null"}, new: $pubkey")
                closeClientIfExists()
            }
            pubkey
        }
    }

    @Volatile
    private var isConnected = false

    @Volatile
    private var accountPubkeyHex: String? = null

    @Volatile
    private var multiClient: MultiClient? = null

    private fun genClientIfNotExists(account: Account, identifier: String?, customClientUrl: String?): MultiClient? {
        return multiClient ?: synchronized(this) {
            try {
                val conf = ClientConfig()
                customClientUrl?.let {
                    conf.seedRPCServerAddr = Nkn.newStringArrayFromString(it)
                    // Nkn.newStringArrayFromString("https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
                }
                multiClient = Nkn.newMultiClient(account, identifier, 3, true, conf)
                multiClient!!
            } catch (e: Exception) {
                closeClientIfExists()
                null
            }
        }
    }

    private fun closeClientIfExists() {
        Log.w("closeClientIfExists", "closeClientIfExists")
        try {
            multiClient?.close()
        } catch (ex: Exception) {
        }
        multiClient = null
        isConnected = false
    }

    fun pauseClient() {
        disConnect(null, null, callFromDart = false)
    }

    fun close() {
        disConnect(null, null, callFromDart = false)
    }
}
