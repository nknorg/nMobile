package org.nkn.sdk.impl

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import nkn.*
import org.nkn.sdk.IChannelHandler
import org.nkn.sdk.NknSdkFlutterPlugin

class Client : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {
    companion object {
        val CHANNEL_NAME = "org.nkn.sdk/client"
        val EVENT_NAME = "org.nkn.sdk/client/event"
    }

    private var numSubClients = 3L
    private var client: MultiClient? = null

    lateinit var methodChannel: MethodChannel
    lateinit var eventChannel: EventChannel
    var eventSink: EventChannel.EventSink? = null

    override fun install(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binaryMessenger, EVENT_NAME)
        eventChannel.setStreamHandler(this)
    }

    override fun uninstall() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                create(call, result)
            }
            "reconnect" -> {
                reconnect(call, result)
            }
            "close" -> {
                close(call, result)
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
            "getHeight" -> {
                getHeight(call, result)
            }
            "getNonce" -> {
                getNonce(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun create(call: MethodCall, result: MethodChannel.Result) {
        val identifier = call.argument<String>("identifier") ?: ""
        val seed = call.argument<ByteArray>("seed")
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")
        numSubClients = (call.argument<Int>("numSubClients") ?: 3).toLong()

        val config = ClientConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }
        // config.rpcConcurrency = 4

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val account = Nkn.newAccount(seed)
                client = MultiClient(account, identifier, numSubClients, true, config)

                val data = hashMapOf(
                    "address" to client?.address(),
                    "publicKey" to client?.pubKey(),
                    "seed" to client?.seed()
                )
                resultSuccess(result, data)

                onConnect(client)
                async(Dispatchers.IO) { onMessage(client) }
            } catch (e: Throwable) {
                resultError(result, "", e.localizedMessage)
            }
        }
    }

    private fun reconnect(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!

        viewModelScope.launch(Dispatchers.IO) {
            try {
                client?.reconnect()
                resultSuccess(result, null)
            } catch (e: Throwable) {
                eventSink?.error(_id, e.localizedMessage, "")
            }
        }
    }

    private fun close(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!

        viewModelScope.launch(Dispatchers.IO) {
            try {
                client?.close()
                client = null
                resultSuccess(result, null)
            } catch (e: Throwable) {
                eventSink?.error(_id, e.localizedMessage, "")
            }
        }
    }

    private suspend fun onConnect(client: MultiClient?) = withContext(Dispatchers.IO) {
        try {
            val node = client?.onConnect?.next() ?: return@withContext
            val rpcServers = ArrayList<String>()
            for (i in 0..numSubClients) {
                val c = client.getClient(i)
                val rpcNode = c?.node
                var rpcAddr = rpcNode?.rpcAddr ?: ""
                if (rpcAddr.isNotEmpty()) {
                    rpcAddr = "http://$rpcAddr"
                    if (!rpcServers.contains(rpcAddr)) {
                        rpcServers.add(rpcAddr)
                    }
                }
            }

            val resp = hashMapOf(
                "_id" to client.address(),
                "event" to "onConnect",
                "node" to hashMapOf("address" to node.addr, "publicKey" to node.pubKey),
                "client" to hashMapOf("address" to client.address()),
                "rpcServers" to rpcServers
            )
            Log.d(NknSdkFlutterPlugin.TAG, resp.toString())
            eventSinkSuccess(eventSink, resp)
        } catch (e: Throwable) {
            eventSinkError(eventSink, client?.address(), e.localizedMessage)
        }
    }

    private suspend fun onMessage(client: MultiClient?) {
        try {
            val msg = client?.onMessage?.next() ?: return
            val resp = hashMapOf(
                "_id" to client.address(),
                "event" to "onMessage",
                "data" to hashMapOf(
                    "src" to msg.src,
                    "data" to String(msg.data, Charsets.UTF_8),
                    "type" to msg.type,
                    "encrypted" to msg.encrypted,
                    "messageId" to msg.messageID
                )
            )
            Log.d(NknSdkFlutterPlugin.TAG, resp.toString())
            eventSinkSuccess(eventSink, resp)
        } catch (e: Throwable) {
            eventSinkError(eventSink, client?.address(), e.localizedMessage)
            return
        }

        // loop
        onMessage(client)
    }


    private fun sendText(call: MethodCall, result: MethodChannel.Result) {
        val dests = call.argument<ArrayList<String>>("dests")!!
        val data = call.argument<String>("data")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds") ?: 0
        val noReply = call.argument<Boolean>("noReply") ?: true
        val timeout = call.argument<Int>("maxHoldingSeconds") ?: 10000

        if (client == null) {
            result.error("", "client is null", "")
            return
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
            result.error("", "dests null", "")
            return
        }

        val config = MessageConfig()
        config.maxHoldingSeconds = if (maxHoldingSeconds < 0) 0 else maxHoldingSeconds
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.noReply = noReply

        viewModelScope.launch(Dispatchers.IO) {
            try {
                if (!noReply) {
                    val onMessage = client?.sendText(nknDests, data, config)
                    val msg = onMessage?.nextWithTimeout(timeout)
                    if (msg == null) {
                        resultSuccess(result, null)
                        return@launch
                    }

                    val resp = hashMapOf(
                        "src" to msg.src,
                        "data" to String(msg.data, Charsets.UTF_8),
                        "type" to msg.type,
                        "encrypted" to msg.encrypted,
                        "messageId" to msg.messageID
                    )
                    resultSuccess(result, resp)
                    return@launch
                } else {
                    client?.sendText(nknDests, data, config)

                    val resp = hashMapOf(
                        "messageId" to config.messageID
                    )
                    resultSuccess(result, resp)
                    return@launch
                }
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun publishText(call: MethodCall, result: MethodChannel.Result) {
        val topic = call.argument<String>("topic")!!
        val data = call.argument<String>("data")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds") ?: 0
        val txPool = call.argument<Boolean>("txPool") ?: false
        val offset = call.argument<Int>("offset") ?: 0
        val limit = call.argument<Int>("limit") ?: 1000

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        val config = MessageConfig()
        config.maxHoldingSeconds = if (maxHoldingSeconds < 0) 0 else maxHoldingSeconds
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.txPool = txPool
        config.offset = offset
        config.limit = limit

        viewModelScope.launch {
            try {
                client?.publishText(topic, data, config)
                val resp = hashMapOf(
                    "messageId" to config.messageID
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun subscribe(call: MethodCall, result: MethodChannel.Result) {
        val identifier = call.argument<String>("identifier") ?: ""
        val topic = call.argument<String>("topic")!!
        val duration = call.argument<Int>("duration")!!
        val meta = call.argument<String>("meta")
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Int>("nonce")

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        if (nonce != null) {
            transactionConfig.nonce = nonce.toLong()
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val hash = client?.subscribe(identifier, topic, duration.toLong(), meta, transactionConfig)
                resultSuccess(result, hash)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun unsubscribe(call: MethodCall, result: MethodChannel.Result) {
        val identifier = call.argument<String>("identifier") ?: ""
        val topic = call.argument<String>("topic")!!
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Int>("nonce")

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        if (nonce != null) {
            transactionConfig.nonce = nonce.toLong()
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val hash = client?.unsubscribe(identifier, topic, transactionConfig)
                resultSuccess(result, hash)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getSubscribers(call: MethodCall, result: MethodChannel.Result) {
        val topic = call.argument<String>("topic")!!
        val offset = call.argument<Int>("offset") ?: 0
        val limit = call.argument<Int>("limit") ?: 0
        val meta = call.argument<Boolean>("meta") ?: true
        val txPool = call.argument<Boolean>("txPool") ?: true
        val subscriberHashPrefix = call.argument<ByteArray>("subscriberHashPrefix")

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val subscribers = client?.getSubscribers(topic, offset.toLong(), limit.toLong(), meta, txPool, subscriberHashPrefix)
                val resp = hashMapOf<String, String>()
                subscribers?.subscribers?.range { addr, value ->
                    resp[addr] = value?.trim() ?: ""
                    true
                }
                if (txPool) {
                    subscribers?.subscribersInTxPool?.range { addr, value ->
                        resp[addr] = value?.trim() ?: ""
                        true
                    }
                }
                resultSuccess(result, resp)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getSubscription(call: MethodCall, result: MethodChannel.Result) {
        val topic = call.argument<String>("topic")!!
        val subscriber = call.argument<String>("subscriber")!!

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val subscription = client?.getSubscription(topic, subscriber)
                val resp = hashMapOf(
                    "meta" to subscription?.meta,
                    "expiresAt" to subscription?.expiresAt
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getSubscribersCount(call: MethodCall, result: MethodChannel.Result) {
        val topic = call.argument<String>("topic")!!
        val subscriberHashPrefix = call.argument<ByteArray>("subscriberHashPrefix")

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val count = client?.getSubscribersCount(topic, subscriberHashPrefix)
                resultSuccess(result, count)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getHeight(call: MethodCall, result: MethodChannel.Result) {
        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val height = client?.height
                resultSuccess(result, height)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getNonce(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")
        val txPool = call.argument<Boolean>("txPool") ?: true

        if (client == null) {
            result.error("", "client is null", "")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val nonce = client?.getNonceByAddress(address, txPool)
                resultSuccess(result, nonce)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }
}