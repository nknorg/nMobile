package org.nkn.sdk.impl

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import nkn.Nkn
import nkn.RPCConfig
import nkn.TransactionConfig
import nkn.WalletConfig
import nkngolib.Nkngolib
import nkngomobile.StringArray
import org.bouncycastle.util.encoders.Hex
import org.nkn.sdk.IChannelHandler

class Wallet : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {
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
            "measureSeedRPCServer" -> {
                measureSeedRPCServer(call, result)
            }
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

    private fun measureSeedRPCServer(call: MethodCall, result: MethodChannel.Result) {
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc") ?: arrayListOf()
        val timeout = call.argument<Int>("timeout") ?: 3000

        var seedRPCServerAddr = StringArray(null)
        for (addr in seedRpc) {
            seedRPCServerAddr.append(addr)
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                seedRPCServerAddr = Nkngolib.measureSeedRPCServer(seedRPCServerAddr, timeout)

                val seedRPCServerAddrs = arrayListOf<String>()
                val elements = seedRPCServerAddr.join(",").split(",")
                for (element in elements) {
                    if (element.isNotEmpty()) {
                        seedRPCServerAddrs.add(element)
                    }
                }

                val resp = hashMapOf(
                    "seedRPCServerAddrList" to seedRPCServerAddrs
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun create(call: MethodCall, result: MethodChannel.Result) {
        val seed = call.argument<ByteArray>("seed") ?: Nkn.randomBytes(32)
        val password = call.argument<String>("password") ?: ""
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        val config = WalletConfig()
        config.password = password
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

                val resp = hashMapOf(
                    "address" to wallet.address(),
                    "keystore" to wallet.toJSON(),
                    "publicKey" to wallet.pubKey(),
                    "seed" to wallet.seed()
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun restore(call: MethodCall, result: MethodChannel.Result) {
        val keystore = call.argument<String>("keystore")
        val password = call.argument<String>("password") ?: ""
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        if (keystore == null) {
            result.success(null)
            return
        }

        val config = WalletConfig()
        config.password = password
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val wallet = Nkn.walletFromJSON(keystore, config)

                val resp = hashMapOf(
                    "address" to wallet.address(),
                    "keystore" to wallet?.toJSON(),
                    "publicKey" to wallet.pubKey(),
                    "seed" to wallet.seed()
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun pubKeyToWalletAddr(call: MethodCall, result: MethodChannel.Result) {
        val pubkey = call.argument<String>("publicKey")

        viewModelScope.launch(Dispatchers.IO) {
            val addr = Nkn.pubKeyToWalletAddr(Hex.decode(pubkey))
            resultSuccess(result, addr)
            return@launch
        }
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

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val wallet = Nkn.newWallet(account, config)
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
        val nonce = call.argument<Int>("nonce")
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
                    transactionConfig.nonce = nonce.toLong()
                    transactionConfig.fixNonce = true
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

    private fun subscribe(call: MethodCall, result: MethodChannel.Result) {
        val seed = call.argument<ByteArray>("seed")
        val identifier = call.argument<String>("identifier") ?: ""
        val topic = call.argument<String>("topic")!!
        val duration = call.argument<Int>("duration")!!
        val meta = call.argument<String>("meta")
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Int>("nonce")
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        if (nonce != null) {
            transactionConfig.nonce = nonce.toLong()
            transactionConfig.fixNonce = true
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val config = WalletConfig()
                if (seedRpc != null) {
                    config.seedRPCServerAddr = StringArray(null)
                    for (addr in seedRpc) {
                        config.seedRPCServerAddr.append(addr)
                    }
                }
                val account = Nkn.newAccount(seed)
                val wallet = Nkn.newWallet(account, config)
                val hash = wallet.subscribe(identifier, topic, duration.toLong(), meta, transactionConfig)

                resultSuccess(result, hash)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun unsubscribe(call: MethodCall, result: MethodChannel.Result) {
        val seed = call.argument<ByteArray>("seed")
        val identifier = call.argument<String>("identifier") ?: ""
        val topic = call.argument<String>("topic")!!
        val fee = call.argument<String>("fee") ?: "0"
        val nonce = call.argument<Int>("nonce")
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        if (nonce != null) {
            transactionConfig.nonce = nonce.toLong()
            transactionConfig.fixNonce = true
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val config = WalletConfig()
                if (seedRpc != null) {
                    config.seedRPCServerAddr = StringArray(null)
                    for (addr in seedRpc) {
                        config.seedRPCServerAddr.append(addr)
                    }
                }
                val account = Nkn.newAccount(seed)
                val wallet = Nkn.newWallet(account, config)
                val hash = wallet.unsubscribe(identifier, topic, transactionConfig)

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
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")
        val subscriberHashPrefix = call.argument<ByteArray>("subscriberHashPrefix")

        val config = RPCConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val subscribers = Nkn.getSubscribers(topic, offset.toLong(), limit.toLong(), meta, txPool, subscriberHashPrefix, config)
                val resp = hashMapOf<String, String>()
                subscribers.subscribers.range { addr, value ->
                    resp[addr] = value?.trim() ?: ""
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

        val config = RPCConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
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
        val subscriberHashPrefix = call.argument<ByteArray>("subscriberHashPrefix")

        val config = RPCConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val count = Nkn.getSubscribersCount(topic, subscriberHashPrefix, config)

                resultSuccess(result, count)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun getHeight(call: MethodCall, result: MethodChannel.Result) {
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        val config = RPCConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val height = Nkn.getHeight(config)

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
        val seedRpc = call.argument<ArrayList<String>?>("seedRpc")

        val config = RPCConfig()
        if (seedRpc != null) {
            config.seedRPCServerAddr = StringArray(null)
            for (addr in seedRpc) {
                config.seedRPCServerAddr.append(addr)
            }
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val nonce = Nkn.getNonce(address, txPool, config)

                resultSuccess(result, nonce)
                return@launch
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }
}