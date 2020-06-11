package org.nkn.nmobile

import android.os.HandlerThread
import android.os.Process
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import nkn.*
import org.nkn.nmobile.NShellClientEventPlugin.Companion.nshellClientEventSink
import org.nkn.nmobile.application.App
import java.util.ArrayList

class NShellClientPlugin : MethodChannel.MethodCallHandler {


    private val msgSendHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgShellSendHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }


    private val msgReceiveHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgShellReceiveHandler", Process.THREAD_PRIORITY_BACKGROUND)
        thread.start()
        android.os.Handler(thread.looper)
    }

    private val connectActionHandler by lazy {
        val thread = HandlerThread(javaClass.name + ".msgShellConnectHandler", Process.THREAD_PRIORITY_BACKGROUND)
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
            else -> {
                result.notImplemented()
            }

        }
    }




    private fun sendText(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val dests = call.argument<ArrayList<String>>("dests") ?: ArrayList()
        val data = call.argument<String>("data") ?: null
        result.success(null)
        if (nshellClientEventSink == null) return

        var nknDests: StringArray? = null
        for (v in dests) {
            if (nknDests == null) {
                nknDests = Nkn.newStringArrayFromString(v)
            } else {
                nknDests.append(v)
            }
        }
        if (nknDests == null) {
            nshellClientEventSink!!.error(_id, "dest  null !!", "")
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
                    nshellClientEventSink!!.success(data)
                }
            } catch (e: Exception) {
                App.handler().post {
                    nshellClientEventSink!!.error(_id, "send failure", "")
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

    private fun disConnect(call: MethodCall?, result: MethodChannel.Result?) {
        try {
            msgReceiveHandler.removeCallbacks(receiveMessagesRun);
        } catch (e: Exception) {
        }
        if (client != null) {
            try {
                client!!.close();
                client = null;
                if(result !=null)
                result.success(1)

            } catch (e: Exception) {
                client = null;
                if(result !=null)
                result.success(0)
            }
        } else {
            if(result !=null)
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
        connectActionHandler.removeCallbacksAndMessages(null);
        result.success(null)
        if (client != null) {
            try {
                msgReceiveHandler.removeCallbacks(receiveMessagesRun);
            } catch (e: Exception) {
            }
            client = null;
        }
        connectActionHandler.post {
            try {
                val account = Nkn.newAccount(wallet.seed())
                client = genClient(account, identifier)
                if (client == null) {
                    App.handler().post {
                        nshellClientEventSink?.error("0", "", "")
                    }
                } else {
                    onConnect()
                }
            } catch (e: Exception) {
                App.handler().post {
                    nshellClientEventSink?.error("0", "", "")
                }
            }
        }
    }


    private fun onConnect() {
//        disConnect(null,null);
        msgReceiveHandler.removeCallbacks(receiveMessagesRun);
        val node = client?.onConnect?.next()
        var data = hashMapOf(
                "event" to "onConnect",
                "node" to hashMapOf("address" to node?.addr, "publicKey" to node?.pubKey),
                "client" to hashMapOf("address" to client?.address())
        )
        App.handler().post {
            nshellClientEventSink?.success(data)
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
                            nshellClientEventSink?.success(data)
                        }
                        onMessage()
                    } else {
                        disConnect(null,null);
//                        msgReceiveHandler.postDelayed({ onMessage() }, 5000)
                    }
                }
            } catch (e: Exception) {
                disConnect(null,null);
//                msgReceiveHandler.postDelayed({ onMessage() }, 5000)
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