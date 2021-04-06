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
import reedsolomon.BytesArray
import reedsolomon.Encoder
import reedsolomon.Reedsolomon
import service.GooglePushService
import java.security.KeyStore
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import kotlin.concurrent.schedule

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

    private var clientList = ArrayList<String>()
    private var mNode:Node = Node()

    private var nullList = IntArray(0)

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
                connectNKN()
                result.success(null)
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
            "intoPieces" -> {
                intoPieces(call, result)
            }
            "combinePieces" -> {
                combinePieces(call, result)
            }
            "nknPush" -> {
                pushContent(call, result)
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
                        "event" to "fetchDeviceToken",
                        "device_token" to deviceToken.toString()
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getDeviceTokenE", "getDeviceToken | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "fetchDeviceToken", e.message)
                }
            }
        }
    }

    /**
     * Check Google Play Service
     */
    private fun onCheckGooglePlayServices(call: MethodCall, result: MethodChannel.Result) {
        val code = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(acty)
        var googleServiceOn:Boolean = false;
        if (code == ConnectionResult.SUCCESS) {
            // 支持Google服务
            googleServiceOn = true
            Log.e("GoogleC","GoogleService Available")
        } else {

            Log.e("GoogleC","GoogleService Unavailable")
        }
        val _id = call.argument<String>("_id")!!
        result.success(null)

        msgSendHandler.post {
            try {
                val _id = call.argument<String>("_id")!!
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "checkGoogleService",
                        "googleServiceOn" to googleServiceOn
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("serviceCheck", "onCheckGooglePlayServices | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "checkGoogleService", e.message)
                }
            }
        }
    }

    private fun onSaveSeedRpc(call: MethodCall?, result: MethodChannel.Result?) {
        var mClient = multiClient?.getClient(-1)
        var mNode = mClient?.node
        if (mNode != null){
            if (mNode?.rpcAddr != null){
                var mNodeAddress:String = "http://"+mNode?.rpcAddr
                App.runOnMainThread{
                    if (!clientList.contains(mNodeAddress)){
                        clientList.add(mNodeAddress)
                    }
                }
            }
        }

        for (index in 0..3) {
            val lIndex: Long = index.toLong()
            var client = multiClient?.getClient(lIndex)
            var rpcNode = client?.node
            if (rpcNode != null){
                if (rpcNode?.rpcAddr != null){
                    var rpcNodeAddress:String = "http://"+rpcNode?.rpcAddr
                    if (!clientList.contains(rpcNodeAddress)){
                        clientList.add(rpcNodeAddress)
                    }
                }
            }
        }

        App.runOnMainThread {
            val clientAddr = multiClient?.address()

            val data = hashMapOf(
                    "event" to "onSaveNodeAddresses",
                    "client" to hashMapOf("clientAddress" to clientAddr,
                            "nodeAddress" to clientList.joinToString(","))
            )
            clientEventSink.success(data)
        }
    }

    private fun createClient(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val identifier = call.argument<String>("identifier")
        val seedBytes = call.argument<ByteArray>("seedBytes")!!
        val clientUrl = call.argument<String>("rpcNodeList")

        if (clientUrl != null){
            var nodeList:List<String> = clientUrl.split(",")
            for (node in nodeList){
                clientList.add(node)
            }
        }

        result.success(null)

        msgSendHandler.post {
            try {
                val account = Nkn.newAccount(seedBytes)
                accountPubkeyHex = account.pubKey().toHex()
                val client = genClientIfNotExists(account, identifier)
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "createClient",
                        "success" to if (client == null) 0 else 1
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
                if (client != null) acty?.onClientCreated()
                connectNKN()
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

    private fun connectNKN() {
        if (isConnected) {
            Log.e("connectNKN", "already Connected")
            val data = hashMapOf(
                    "event" to "onConnect",
                    "node" to hashMapOf("address" to "reconnect", "publicKey" to "node"),
                    "client" to hashMapOf("address" to this.multiClient?.address())
            )
            App.runOnMainThread {
                Log.e("connectNKN", "already Connected call back")
                clientEventSink.success(data)
            }
            return
        }

        if (multiClient == null) {
            Log.e("connectNKN", "create Client First")
            return
        }
        msgSendHandler.post {
            try {
                var node = this.multiClient?.onConnect?.next()
                if (node == null) {
                    return@post
                }
                mNode = node
                isConnected = true
                val data = hashMapOf(
                        "event" to "onConnect",
                        "node" to hashMapOf("address" to node.addr, "publicKey" to node.pubKey),
                        "client" to hashMapOf("address" to this.multiClient?.address()))
                App.runOnMainThread {
                    Log.e("connectNKN", "Connect NKN End")
                    clientEventSink.success(data)

                    Timer().schedule(10000){
                        onSaveSeedRpc(null,null);
                    }
                }
            }
            catch (e: Exception) {
                Log.e("connectNKN", "Connect E:", e)
            }
        }
        receiveMessages()
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
                    Log.e("Log.e","onLoop Received")
                    receiveMessages()
                }
            } catch (e: Exception) {
                Log.e("receiveMessagesRun", "receiveMessages | e:", e)
                msgReceiveHandler.postDelayed({ receiveMessages() }, 5000)
            }
        }
    }

    private fun pushContent(call: MethodCall, result: MethodChannel.Result){
        var deviceToken = call.argument<String>("deviceToken")!!
        var pushContent = call.argument<String>("pushContent")!!

        if (deviceToken.isNotEmpty()){
            val code = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(acty)
            if (code == ConnectionResult.SUCCESS && pushContent?.length > 0){
                if (deviceToken?.length >= 32){
                    val service = GooglePushService()
                    service.sendMessageToFireBase(deviceToken, pushContent)
                }
            }
        }
    }

    private fun sendText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val dests = call.argument<ArrayList<String>>("dests")!!
        val data = call.argument<String>("data")!!
        val msgId = call.argument<String>("msgId")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds")!!

        result.success(null)

        val dataObj = JSONObject(data)
        if (dataObj.optString("deviceToken").isNotEmpty()){
            val deviceToken = dataObj["deviceToken"].toString()
            val pushContent = dataObj["pushContent"].toString()
            val code = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(acty)
            if (code == ConnectionResult.SUCCESS && pushContent?.length > 0){
                if (deviceToken?.length >= 32){
                    val service = GooglePushService()
                    service.sendMessageToFireBase(deviceToken, pushContent)
                }
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
                clientEventSink.error(_id, "sendText", "dests null")
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
                        "event" to "sendText",
                        "pid" to config.messageID,
                        "msgId" to msgId
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("sendTextE", "sendText | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "sendText", e.message)
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
                        "event" to "publishText",
                        "pid" to config.messageID
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("publishTextE", "publishText | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "publishText", e.message)
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
                        "event" to "subscribe",
                        "data" to hash
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("subscribeE", "subscribe | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "subscribe", e.message)
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
                        "event" to "unsubscribe",
                        "data" to hash
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("unsubscribe", "unsubscribe | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "unsubscribe", e.message)
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

                var dataMap = HashMap<String, String>()
                subscribers.subscribersInTxPool.range { chatId, value ->
                    val meta = value?.trim() ?: ""
                    dataMap[chatId] = meta
                    true
                }
                subscribers.subscribers.range { chatId, value ->
                    val meta = value?.trim() ?: ""
                    dataMap[chatId] = meta
                    true
                }
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "getSubscribers",
                        "data" to dataMap
                )

                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getSubscribers", "getSubscribers | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "getSubscribers", e.message)
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
                val data = hashMapOf(
                        "meta" to subscription.meta,
                        "expiresAt" to subscription.expiresAt
                )
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "getSubscription",
                        "data" to data
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getSubscriptionE", "getSubscription | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "getSubscription", e.message)
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
                        "event" to "getBlockHeight",
                        "height" to height
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getBlockHeightE", "getSubscription | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "getBlockHeight", e.message)
                }
            }
        }
    }

    private fun fetchDebugInfo(call: MethodCall, result: MethodChannel.Result){
        val ks: KeyStore = KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        val aliases: Enumeration<String> = ks.aliases()

        var keyStoreAliases:String = ""
        while (aliases.hasMoreElements()){
            val alias:String = aliases.nextElement();
            keyStoreAliases = keyStoreAliases+alias;
        }

        val _id = call.argument<String>("_id")!!
        result.success(null)

        msgSendHandler.post {
            try {
                val _id = call.argument<String>("_id")!!
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "fetchDebugInfo",
                        "debugInfo" to keyStoreAliases
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("fetchDebugInfoE", "fetchDebugInfoE | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "fetchDebugInfo", e.message)
                }
            }
        }
    }

    private fun intoPieces(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val flutterDataString = call.argument<String>("data") ?: ""
        val dataShards = call.argument<Int>("dataShards")!!
        val parityShards = call.argument<Int>("parityShards")!!

        val encoder: Encoder? = Reedsolomon.newDefault(dataShards.toLong(), parityShards.toLong());
        val dataBytes: BytesArray? = encoder?.splitBytesArray(flutterDataString.toByteArray())

        encoder?.encodeBytesArray(dataBytes)

        var dataBytesArray = ArrayList<ByteArray>()

        var totalPieces:Int = dataShards+parityShards-1
        for(index:Int in 0..totalPieces){
            var theBytes = dataBytes?.get(index.toLong())
            if (theBytes != null) {
                dataBytesArray.add(theBytes)
            }
        }

        msgSendHandler.post{
            try {
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "intoPieces",
                        "data" to dataBytesArray
                )
                Log.e("intoPiecesE", "intoPieces | e:"+resp.toString())
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("intoPiecesE", "intoPieces | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "subscribe", e.message)
                }
            }
        }
    }

    private fun combinePieces(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val fDataList = call.argument<ArrayList<ByteArray>>("data") !!
        val dataShards = call.argument<Int>("dataShards")!!
        val parityShards = call.argument<Int>("parityShards")!!
        val bytesLength = call.argument<Int>("bytesLength")!!

        val service = GooglePushService()
        val result:String = service.combineBytesArray(fDataList,dataShards,parityShards,bytesLength);
        msgSendHandler.post{
            try {
                val resp = hashMapOf(
                        "_id" to _id,
                        "event" to "combinePieces",
                        "data" to result
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("subscribeE", "subscribe | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "subscribe", e.message)
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
                        "event" to "getSubscribersCount",
                        "_id" to _id,
                        "data" to count
                )
                App.runOnMainThread {
                    clientEventSink.success(resp)
                }
            } catch (e: Exception) {
                Log.e("getSubscribersCount", "getSubscribersCount | e:", e)
                App.runOnMainThread {
                    clientEventSink.error(_id, "getSubscribersCount", e.message)
                }
            }
        }
    }

    @Volatile
    private var isConnected = false

    @Volatile
    private var accountPubkeyHex: String? = null

    @Volatile
    private var multiClient: MultiClient? = null

    private fun genClientIfNotExists(account: Account, identifier: String?): MultiClient? {
        return multiClient ?: synchronized(this) {
            try {
                val conf = ClientConfig()
                if (clientList.count() > 1 && clientList[0].isNotEmpty()) {
                    if (clientList.size > 0) {
                        var seedRpcArray: StringArray = Nkn.newStringArrayFromString(clientList[0])
                        for (index in clientList.indices) {
                            var rpcNodeAddress: String = clientList[index]
                            if (index != 0) {
                                seedRpcArray.append(rpcNodeAddress)
                            }
                        }
                        var measuredArray = Nkn.measureSeedRPCServer(seedRpcArray, 1500)
                        conf.seedRPCServerAddr = measuredArray
                    } else {
                        conf.seedRPCServerAddr = Nkn.newStringArrayFromString("http://seed.nkn.org:30003")
                        multiClient = Nkn.newMultiClient(account, identifier, 3, true, conf)
                    }
                }
                conf.wsWriteTimeout = 20000
                multiClient = Nkn.newMultiClient(account, identifier, 3, true, conf)
                multiClient!!
            } catch (e: Exception) {
                val conf = ClientConfig()
                conf.seedRPCServerAddr = Nkn.newStringArrayFromString("http://seed.nkn.org:30003")
                Log.w("genClientIfNotExists", conf.rpcGetConcurrency().toString())
                conf.wsWriteTimeout = 20000
                multiClient = Nkn.newMultiClient(account, identifier, 3, true, conf)
                null
            }
        }
    }

    private fun closeClientIfExists() {
        Log.w("closeClientIfExists", "closeClientIfExists")
        try {
            multiClient?.close()
        } catch (ex: Exception) {
            Log.w("closeClientIfExistsE", ex.toString())
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
