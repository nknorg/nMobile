package org.nkn.sdk.impl

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import nkn.*
import nkngolib.Nkngolib
import nkngomobile.Nkngomobile.newStringArrayFromString
import nkngomobile.StringArray
import org.bouncycastle.util.encoders.Hex
import org.nkn.sdk.IChannelHandler

class Client : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    ViewModel() {
    companion object {
        val CHANNEL_NAME = "org.nkn.sdk/client"
        val EVENT_NAME = "org.nkn.sdk/client/event"
    }

    lateinit var methodChannel: MethodChannel
    lateinit var eventChannel: EventChannel
    var eventSink: EventChannel.EventSink? = null

    private var clientMap: HashMap<String, MultiClient> = hashMapOf()

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

    private suspend fun createClient(
        account: Account,
        identifier: String,
        numSubClients: Long,
        config: ClientConfig
    ): MultiClient = withContext(Dispatchers.IO) {
        val pubKey = Hex.toHexString(account.pubKey())
        val id = if (identifier.isEmpty()) pubKey else "${identifier}.${pubKey}"

        closeClient(id)

        val client = MultiClient(account, identifier, numSubClients, true, config)
        clientMap[client.address()] = client
        client
    }

    private suspend fun closeClient(id: String) = withContext(Dispatchers.IO) {
        val client = (if (clientMap.containsKey(id)) clientMap[id] else null) ?: return@withContext

        try {
            if (client.isClosed) {
                client.close()
            }
            clientMap.remove(id)
        } catch (e: Throwable) {
            throw e
        }
    }

    private suspend fun onConnect(client: MultiClient, numSubClients: Long) =
        withContext(Dispatchers.IO) {
            try {
                val node = client.onConnect.next() ?: return@withContext

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
                //Log.d(NknSdkFlutterPlugin.TAG, resp.toString())
                eventSinkSuccess(eventSink, resp)
            } catch (e: Throwable) {
                eventSinkError(eventSink, client.address(), e.localizedMessage)
            }
        }

    private suspend fun onMessage(client: MultiClient) {
        withContext(Dispatchers.IO) {
            while (!client.isClosed) {
                try {
                    val msg = client.onMessage.next() ?: continue

                    val resp = hashMapOf(
                        "_id" to client.address(),
                        "event" to "onMessage",
                        "data" to hashMapOf(
                            "src" to msg.src,
                            "data" to String(msg.data, Charsets.UTF_8),
                            "type" to msg.type,
                            "encrypted" to msg.encrypted,
                            "messageId" to msg.messageID,
                            "noReply" to msg.noReply
                        )
                    )
                    //Log.d(NknSdkFlutterPlugin.TAG, resp.toString())
                    eventSinkSuccess(eventSink, resp)
                } catch (e: Throwable) {
                    eventSinkError(eventSink, client.address(), e.localizedMessage)
                }
            }
        }
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
            "replyText" -> {
                replyText(call, result)
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
        val numSubClients = (call.argument<Int>("numSubClients") ?: 3).toLong()
        val connectRetries = call.argument<Int>("connectRetries") ?: -1
        val maxReconnectInterval = call.argument<Int>("maxReconnectInterval") ?: 5000
        val ethResolverConfigArray =
            call.argument<ArrayList<Map<String, Any>>?>("ethResolverConfigArray")
        val dnsResolverConfigArray =
            call.argument<ArrayList<Map<String, Any>>?>("dnsResolverConfigArray")

        val config = ClientConfig()

        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        config.connectRetries = connectRetries
        config.maxReconnectInterval = maxReconnectInterval

        if (ethResolverConfigArray != null) {
            for (cfg in ethResolverConfigArray) {
                val ethResolverConfig: ethresolver.Config = ethresolver.Config()
                ethResolverConfig.prefix = cfg["prefix"] as String?
                ethResolverConfig.rpcServer = cfg["rpcServer"] as String?
                ethResolverConfig.contractAddress = cfg["contractAddress"] as String?
                val ethResolver: ethresolver.Resolver = ethresolver.Resolver(ethResolverConfig)
                if (config.resolvers == null) {
                    config.resolvers = nkngomobile.ResolverArray(ethResolver)
                } else {
                    config.resolvers.append(ethResolver)
                }
            }
        }

        if (dnsResolverConfigArray != null) {
            for (cfg in dnsResolverConfigArray) {
                val dnsResolverConfig: dnsresolver.Config = dnsresolver.Config()
                dnsResolverConfig.dnsServer = cfg["dnsServer"] as String?
                val dnsResolver: dnsresolver.Resolver = dnsresolver.Resolver(dnsResolverConfig)
                if (config.resolvers == null) {
                    config.resolvers = nkngomobile.ResolverArray(dnsResolver)
                } else {
                    config.resolvers.append(dnsResolver)
                }
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val account = Nkn.newAccount(seed)
                var client: MultiClient? = null
                try {
                    client = createClient(account, identifier, numSubClients, config)
                } catch (_: Throwable) {
                }
                if (client == null) {
                    Nkngolib.addClientConfigWithDialContext(config)
                    client = createClient(account, identifier, numSubClients, config)
                }
                if (client == null) {
                    resultError(result, "", "client create fail", "create")
                    return@launch
                }
                // result
                val data = hashMapOf(
                    "address" to client.address(),
                    "publicKey" to client.pubKey(),
                    "seed" to client.seed()
                )
                resultSuccess(result, data)

                onConnect(client, numSubClients)

                onMessage(client)
            } catch (e: Throwable) {
                resultError(result, e)
            }
        }
    }

    private fun reconnect(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "reconnect")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "reconnect")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                client.reconnect()

                resultSuccess(result, null)
            } catch (e: Throwable) {
                resultError(result, e)
            }
        }
    }

    private fun close(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "close")
            return
        } else if (client.isClosed) {
            result.success(null)
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                closeClient(_id)
                resultSuccess(result, null)
            } catch (e: Throwable) {
                resultError(result, e)
            }
        }
    }

    private fun replyText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val messageId = call.argument<ByteArray>("messageId")
        val dest = call.argument<String>("dest")!!
        val data = call.argument<String>("data")!!
        val encrypted = call.argument<Boolean>("encrypted") ?: true
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds") ?: 0

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "replyText")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "replyText")
            return
        }

        val msg = Message()
        msg.messageID = messageId
        msg.src = dest

        viewModelScope.launch(Dispatchers.IO) {
            try {
                Nkngolib.reply(client, msg, data, encrypted, maxHoldingSeconds)
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun sendText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val dests = call.argument<ArrayList<String>>("dests")!!
        val data = call.argument<String>("data")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds") ?: 0
        val noReply = call.argument<Boolean>("noReply") ?: true
        val timeout = call.argument<Int>("timeout") ?: 10000

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "sendText")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "sendText")
            return
        }

        var nknDests: StringArray? = null
        for (d in dests) {
            if (nknDests == null) {
                nknDests = newStringArrayFromString(d)
            } else {
                nknDests.append(d)
            }
        }
        if (nknDests == null) {
            result.error("", "dests is empty", "sendText")
            return
        }

        val config = MessageConfig()
        config.maxHoldingSeconds = if (maxHoldingSeconds < 0) 0 else maxHoldingSeconds
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.noReply = noReply

        viewModelScope.launch(Dispatchers.IO) {
            try {
                if (!noReply) {
                    val onMessage = client.sendText(nknDests, data, config)
                    if (onMessage == null) {
                        resultError(result, "", "onMessage is null", "sendText")
                        return@launch
                    }
                    val msg = onMessage.nextWithTimeout(timeout)
                    if (msg == null) {
                        resultError(result, "", "wait reply timeout", "sendText")
                        return@launch
                    }
                    val resp = hashMapOf(
                        "src" to msg.src,
                        "data" to String(msg.data, Charsets.UTF_8),
                        "type" to msg.type,
                        "encrypted" to msg.encrypted,
                        "messageId" to msg.messageID,
                        "noReply" to msg.noReply
                    )
                    resultSuccess(result, resp)
                    return@launch
                } else {
                    client.sendText(nknDests, data, config)

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
        val _id = call.argument<String>("_id")!!
        val topic = call.argument<String>("topic")!!
        val data = call.argument<String>("data")!!
        val maxHoldingSeconds = call.argument<Int>("maxHoldingSeconds") ?: 0
        val txPool = call.argument<Boolean>("txPool") ?: false
        val offset = call.argument<Int>("offset") ?: 0
        val limit = call.argument<Int>("limit") ?: 1000

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "publishText")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "publishText")
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
                client.publishText(topic, data, config)

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
        val _id = call.argument<String>("_id")!!
        val identifier = call.argument<String>("identifier") ?: ""
        val topic = call.argument<String>("topic")!!
        val duration = call.argument<Int>("duration")!!
        val meta = call.argument<String>("meta")
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Int>("nonce")

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "subscribe")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "subscribe")
            return
        }

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        if (nonce != null) {
            transactionConfig.nonce = nonce.toLong()
            transactionConfig.fixNonce = true
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val hash = client.subscribe(
                    identifier,
                    topic,
                    duration.toLong(),
                    meta,
                    transactionConfig
                )

                resultSuccess(result, hash)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun unsubscribe(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val identifier = call.argument<String>("identifier") ?: ""
        val topic = call.argument<String>("topic")!!
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Int>("nonce")

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "unsubscribe")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "unsubscribe")
            return
        }

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        if (nonce != null) {
            transactionConfig.nonce = nonce.toLong()
            transactionConfig.fixNonce = true
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val hash = client.unsubscribe(identifier, topic, transactionConfig)

                resultSuccess(result, hash)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getSubscribers(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val topic = call.argument<String>("topic")!!
        val offset = call.argument<Int>("offset") ?: 0
        val limit = call.argument<Int>("limit") ?: 0
        val meta = call.argument<Boolean>("meta") ?: true
        val txPool = call.argument<Boolean>("txPool") ?: true
        val subscriberHashPrefix = call.argument<ByteArray>("subscriberHashPrefix")

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "getSubscribers")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "getSubscribers")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val subscribers = client.getSubscribers(
                    topic,
                    offset.toLong(),
                    limit.toLong(),
                    meta,
                    txPool,
                    subscriberHashPrefix
                )

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
        val _id = call.argument<String>("_id")!!
        val topic = call.argument<String>("topic")!!
        val subscriber = call.argument<String>("subscriber")!!

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "getSubscription")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "getSubscription")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val subscription = client.getSubscription(topic, subscriber)

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
        val _id = call.argument<String>("_id")!!
        val topic = call.argument<String>("topic")!!
        val subscriberHashPrefix = call.argument<ByteArray>("subscriberHashPrefix")

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "getSubscribersCount")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "getSubscribersCount")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val count = client.getSubscribersCount(topic, subscriberHashPrefix)

                resultSuccess(result, count)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getHeight(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "getHeight")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "getHeight")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val height = client.height

                resultSuccess(result, height)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getNonce(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id")!!
        val address = call.argument<String>("address")
        val txPool = call.argument<Boolean>("txPool") ?: true

        val client = if (clientMap.containsKey(_id)) clientMap[_id] else null
        if (client == null) {
            result.error("", "client is null", "getNonce")
            return
        } else if (client.isClosed) {
            result.error("", "client is closed", "getNonce")
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val nonce = client.getNonceByAddress(address, txPool)

                resultSuccess(result, nonce)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }
}