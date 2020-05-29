package org.nkn.nmobile

import android.os.HandlerThread
import android.os.Process
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import nkn.*
import org.json.JSONObject
import org.nkn.mobile.app.util.Bytes2String.toHex
import org.nkn.nmobile.NknClientEventPlugin.Companion.clientEventSink
import org.nkn.nmobile.application.App
import java.util.ArrayList
import java.util.concurrent.Executors

class NknClientPlugin : MethodChannel.MethodCallHandler {


    private val walletPluginHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".NknWalletPlugin", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val msgSendHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgSendHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val msgPublishSendHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgPublishSendHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val msgReceiveHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgReceiveHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val connectActionHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgConnectHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createClient" -> {
                createClient(call, result)
            }
            "isConnected" -> {
                isConnected(call, result)
            }
            "disConnect" -> {
                disConnect(call, result)
            }
            "sendText" -> {
                sendText(call, result)
            }
            "publish" -> {
                publish(call, result)
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
            "getSubscription" -> {
                getSubscription(call, result)
            }
            "getSubscribers" -> {
                getSubscribers(call, result)
            }
            else -> {
                result.notImplemented()
            }

        }
    }


    private fun getSubscribers(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val topic = call.argument<String>("topic") ?: null
        val offset = call.argument<Int>("offset") ?: 0
        val limit = call.argument<Int>("limit") ?: 0
        val meta = call.argument<Boolean>("meta") ?: false
        val txPool = call.argument<Boolean>("txPool") ?: false


        result.success(null)
        walletPluginHandler.post {
            val subscribers = client?.getSubscribers(topic, offset.toLong(), limit.toLong(), meta, txPool)

            val map = HashMap<String, String>()
            map.put("_id", _id!!);

            subscribers?.subscribers?.range { chatId, value ->
                val meta = value?.trim() ?: ""
                map.put(chatId, meta)
                true
            }

            App.handler().post {
                clientEventSink?.success(map)
            }
        }

    }

    private fun getSubscription(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val topic = call.argument<String>("topic") ?: null
        val subscriber = call.argument<String>("subscriber") ?: null


        result.success(null)
        walletPluginHandler.post {
            try {
                val scription = client?.getSubscription(topic, subscriber)
                val map = hashMapOf(
                        "_id" to _id,
                        "meta" to scription?.meta,
                        "expiresAt" to scription?.expiresAt
                )
                App.handler().post {
                    clientEventSink?.success(map)
                }
            } catch (e: Exception) {
                App.handler().post {
                    clientEventSink?.error(_id, e.message, null);
                }
            }
        }
    }


    private fun getSubscribersCount(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val topic = call.argument<String>("topic") ?: null

        result.success(null)
        walletPluginHandler.post {
            try {
                val count = client?.getSubscribersCount(topic)
                val map = hashMapOf(
                        "_id" to _id,
                        "result" to count
                )
                App.handler().post {
                    clientEventSink?.success(map)
                }
            } catch (e: Exception) {
                clientEventSink?.error(_id, e.message, null);
            }
        }
    }


    private fun unsubscribe(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val identifier = call.argument<String>("identifier") ?: null
        val topic = call.argument<String>("topic") ?: null
        val fee = call.argument<String>("fee") ?: null


        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee

        result.success(null)
        walletPluginHandler.post {
            val hash = client?.unsubscribe(identifier, topic, transactionConfig)
            val map = hashMapOf(
                    "_id" to _id,
                    "result" to hash
            )
            App.handler().post {
                clientEventSink?.success(map)
            }
        }
    }

    private fun subscribe(call: MethodCall, result: MethodChannel.Result) {

        val _id = call.argument<String>("_id") ?: null
        val identifier = call.argument<String>("identifier") ?: null
        val topic = call.argument<String>("topic") ?: null
        val duration = call.argument<Int>("duration") ?: 0
        val meta = call.argument<String>("meta") ?: null
        val fee = call.argument<String>("fee") ?: null
        result.success(null)
        if (clientEventSink == null) return
        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee

        try {
            walletPluginHandler.post {
                val hash = client?.subscribe(identifier, topic, duration.toLong(), meta, transactionConfig)
                val map = hashMapOf(
                        "_id" to _id,
                        "result" to hash
                )
                App.handler().post {
                    print(hash)
                    print(map)
                    clientEventSink?.success(map)
                }
            }
        } catch (e: Exception) {
            App.handler().post {
                clientEventSink?.error(_id, "", "")
            }
        }
    }

    private fun publish(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val topic = call.argument<String>("topic") ?: null
        val data = call.argument<String>("data") ?: null
        result.success(null)
        if (clientEventSink == null) return
        val config = MessageConfig()
        config.maxHoldingSeconds = Int.MAX_VALUE
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.noReply = true
        msgPublishSendHandler.post {
            try {
                client?.publishText(topic, data, config)
                var data = hashMapOf(
                        "_id" to _id,
                        "event" to "send",
                        "pid" to config.messageID
                )
                App.handler().post {
                    clientEventSink?.success(data)
                }
            } catch (e: Exception) {
                App.handler().post {
                    clientEventSink?.error(_id, "", "")
                }
            }
        }
    }


    private fun sendText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val dests = call.argument<ArrayList<String>>("dests") ?: ArrayList()
        val data = call.argument<String>("data") ?: null
        result.success(null)
        if (clientEventSink == null) return

        var nknDests: StringArray? = null
        for (v in dests) {
            if (nknDests == null) {
                nknDests = Nkn.newStringArrayFromString(v)
            } else {
                nknDests.append(v)
            }
        }
        if (nknDests == null) {
            clientEventSink!!.error(_id, "dest  null !!", "")
            return
        }

        val config = MessageConfig()
        config.maxHoldingSeconds = Int.MAX_VALUE
        config.messageID = Nkn.randomBytes(Nkn.MessageIDSize)
        config.noReply = true
        msgSendHandler.post {
            try {
                client?.sendText(nknDests, data, config)
                var data = hashMapOf(
                        "_id" to _id,
                        "event" to "send",
                        "pid" to config.messageID
                )
                App.handler().post {
                    clientEventSink!!.success(data)
                }
            } catch (e: Exception) {
                App.handler().post {
                    clientEventSink!!.error(_id, "", "")
                }
            }
        }
    }


    private fun isConnected(call: MethodCall, result: MethodChannel.Result) {
        if (client != null) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun disConnect(call: MethodCall, result: MethodChannel.Result) {
        if (client != null) {
            try {
                msgReceiveHandler.removeCallbacks(receiveMessagesRun);
            } catch (e: Exception) {
            }

            try {
                client?.close();
                client = null;
                result.success(1)

            } catch (e: Exception) {
                client = null;
                result.success(0)
            }
        } else {
            result.success(1)
        }
    }


    private fun createClient(call: MethodCall, result: MethodChannel.Result) {
        val identifier = call.argument<String>("identifier") ?: null
        val keystore = call.argument<String>("keystore") ?: null
        val password = call.argument<String>("password") ?: ""
        val config = WalletConfig()
        config.password = password

        val wallet = Nkn.walletFromJSON(keystore, config)

        result.success(null)
        if (client != null) {
            return
        }
        connectActionHandler.removeCallbacksAndMessages(null);
        connectActionHandler.post {
            try {
                val account = Nkn.newAccount(wallet.seed())
                client = genClient(account, identifier)
                if (client == null) {
                    App.handler().post {
                        clientEventSink?.error("0", "", "")
                    }
                } else {
                    onConnect()
                }
            } catch (e: Exception) {
                App.handler().post {
                    clientEventSink?.error("0", "", "")
                }
            }
        }
    }


    private fun onConnect() {
        val node = client?.onConnect?.next()
        var data = hashMapOf(
                "event" to "onConnect",
                "node" to hashMapOf("address" to node?.addr, "publicKey" to node?.pubKey),
                "client" to hashMapOf("address" to client?.address())
        )
        App.handler().post {
            clientEventSink?.success(data)
        }
        onMessage()
    }

    private fun onMessage() {
        msgReceiveHandler.removeCallbacks(receiveMessagesRun)
        msgReceiveHandler.post(receiveMessagesRun)
    }

    private val receiveMessagesRun: Runnable by lazy {
        Runnable {
            try {
                val msgClient = client
                msgClient?.let { clientv ->
                    val msg = clientv.onMessage.next()
                    if (msg != null) {
                        var data = hashMapOf(
                                "event" to "onMessage",
                                "data" to hashMapOf(
                                        "src" to msg?.src,
                                        "data" to String(msg!!.data, Charsets.UTF_8),
                                        "type" to msg?.type,
                                        "encrypted" to msg?.encrypted,
                                        "pid" to msg?.messageID
                                )
                        )
                        App.handler().post {
                            clientEventSink?.success(data)
                        }
                        onMessage()
                    } else {
                        msgReceiveHandler.postDelayed({ onMessage() }, 5000)
                    }
                }
            } catch (e: Exception) {
                msgReceiveHandler.postDelayed({ onMessage() }, 5000)
            }
        }
    }


    @Volatile
    private var client: MultiClient? = null

    private fun genClient(account: Account, identifier: String?): MultiClient? {
        return client ?: synchronized(this) {
            try {
                val conf = ClientConfig()
                conf.seedRPCServerAddr =
                        Nkn.newStringArrayFromString("https://mainnet-rpc-node-0001.nkn.org/mainnet/api/wallet")
                client = Nkn.newMultiClient(account, identifier, 3, true, conf)
                client!!
            } catch (e: Exception) {
                try {
                    client?.close()
                } catch (ex: Exception) {
                }
                client = null
                null
            }
        }
    }


}