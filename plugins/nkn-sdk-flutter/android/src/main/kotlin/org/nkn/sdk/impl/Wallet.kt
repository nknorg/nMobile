package org.nkn.sdk.impl

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import nkn.*
import org.nkn.sdk.IChannelHandler
import org.bouncycastle.util.encoders.Hex

class Wallet : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    ViewModel() {
    companion object {
        val CHANNEL_NAME = "org.nkn.sdk/wallet"
    }

    lateinit var methodChannel: MethodChannel
    var eventSink: EventChannel.EventSink? = null

    override fun install(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
    }

    override fun uninstall() {
        methodChannel.setMethodCallHandler(null)
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
            "restore" -> {
                restore(call, result)
            }
            "pubKeyToWalletAddr" -> {
                pubKeyToWalletAddr(call, result)
            }
            "getBalance" -> {
                getBalance(call, result)
            }
            "transfer" -> {
                transfer(call, result)
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
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun create(call: MethodCall, result: MethodChannel.Result) {
        val seed = call.argument<ByteArray>("seed") ?: Nkn.randomBytes(32)
        val password = call.argument<String>("password") ?: ""
        val account = Nkn.newAccount(seed)
        val config = WalletConfig()
        config.password = password
        val wallet = Nkn.newWallet(account, config)
        val json = wallet.toJSON()
        val resp = hashMapOf(
            "address" to wallet.address(),
            "keystore" to json,
            "publicKey" to wallet.pubKey(),
            "seed" to wallet.seed()
        )
        result.success(resp)
    }

    private fun restore(call: MethodCall, result: MethodChannel.Result) {
        val keystore = call.argument<String>("keystore")
        val password = call.argument<String>("password") ?: ""
        if (keystore == null) {
            result.success(null)
            return
        }
        val config = WalletConfig()
        config.password = password
        try {
            val wallet = Nkn.walletFromJSON(keystore, config)
            val json = wallet?.toJSON()
            val resp = hashMapOf(
                "address" to wallet.address(),
                "keystore" to json,
                "publicKey" to wallet.pubKey(),
                "seed" to wallet.seed()
            )
            result.success(resp)
        } catch (e: Throwable) {
            result.error("", e.localizedMessage, e.message)
        }
    }

    private fun pubKeyToWalletAddr(call: MethodCall, result: MethodChannel.Result) {
        val pubkey = call.argument<String>("publicKey")

        val addr = Nkn.pubKeyToWalletAddr(Hex.decode(pubkey))
        result.success(addr)
    }

    private fun getBalance(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")
        val account = Nkn.newAccount(Nkn.randomBytes(32))

        val config = WalletConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }
        val wallet = Nkn.newWallet(account, config)
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val balance = wallet.balanceByAddress(address).toString()
                resultSuccess(result, balance.toDouble())
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun transfer(call: MethodCall, result: MethodChannel.Result) {
        val seed = call.argument<ByteArray>("seed")
        val address = call.argument<String>("address")
        val amount = call.argument<String>("amount") ?: "0"
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Long>("nonce")
        val attributes = call.argument<ByteArray>("attributes")
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")
        val config = WalletConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val account = Nkn.newAccount(seed)
                val wallet = Nkn.newWallet(account, config)
                val transactionConfig = TransactionConfig()
                transactionConfig.fee = fee
                if (nonce != null) {
                    transactionConfig.nonce = nonce
                }
                if (attributes != null) {
                    transactionConfig.attributes = attributes
                }

                val hash = wallet.transfer(address, amount, transactionConfig)
                resultSuccess(result, hash)
                return@launch
            } catch (e: Throwable) {
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
        val txPool = call.argument<Boolean>("txPool") ?: false
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val config = RPCConfig()
                if (seedRpc != null) {
                    config.seedRPCServerAddr = StringArray(null)
                    for (addr in seedRpc) {
                        config.seedRPCServerAddr.append(addr)
                    }
                }
                val subscribers =
                    Nkn.getSubscribers(topic, offset.toLong(), limit.toLong(), meta, txPool, config)

                val resp = hashMapOf<String, String>()

                subscribers.subscribers.range { addr, value ->
                    val meta = value?.trim() ?: ""
                    resp[addr] = meta
                    true
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
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val config = RPCConfig()
                if (seedRpc != null) {
                    config.seedRPCServerAddr = StringArray(null)
                    for (addr in seedRpc) {
                        config.seedRPCServerAddr.append(addr)
                    }
                }
                val subscription = Nkn.getSubscription(topic, subscriber, config)
                val resp = hashMapOf(
                    "meta" to subscription.meta,
                    "expiresAt" to subscription.expiresAt
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
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val config = RPCConfig()
                if (seedRpc != null) {
                    config.seedRPCServerAddr = StringArray(null)
                    for (addr in seedRpc) {
                        config.seedRPCServerAddr.append(addr)
                    }
                }
                val count = Nkn.getSubscribersCount(topic, config)
                resultSuccess(result, count)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }
}