package org.nkn.mobile.app

import android.os.AsyncTask
import android.security.keystore.KeyInfo
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import nkn.Nkn
import nkn.TransactionConfig
import nkn.WalletConfig
import org.nkn.mobile.app.util.Bytes2String.decodeHex
import org.nkn.mobile.app.util.Bytes2String.toHex
import java.security.KeyStore
import java.util.*

class NknWalletPlugin(flutterEngine: FlutterEngine) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val N_MOBILE_SDK_WALLET = "org.nkn.sdk/wallet"
        private const val N_MOBILE_SDK_WALLET_EVENT = "org.nkn.sdk/wallet/event"
    }

    init {
        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_WALLET).setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_WALLET_EVENT).setStreamHandler(this)
    }

    var walletEventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        walletEventSink = events
    }

    override fun onCancel(arguments: Any?) {
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createWallet" -> {
                createWallet(call, result)
            }
            "restoreWallet" -> {
                restoreWallet(call, result)
            }
            "getBalance" -> {
                getBalance(call, result)
            }
            "getBalanceAsync" -> {
                getBalanceAsync(call, result)
            }
            "transfer" -> {
                transfer(call, result)
            }
            "transferAsync" -> {
                transferAsync(call, result)
            }
            "openWallet" -> {
                openWallet(call, result)
            }
            "pubKeyToWalletAddr" -> {
                pubKeyToWalletAddr(call, result)
            }
            "fetchDebugInfo" -> {
                fetchDebugInfo(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }



    private fun pubKeyToWalletAddr(call: MethodCall, result: MethodChannel.Result) {
        val pubkey = call.argument<String>("publicKey") ?: null

        try {
            result.success(Nkn.pubKeyToWalletAddr(pubkey?.decodeHex()))
        }catch (e : Exception){
            result.error("0", e.localizedMessage, "")
        }
    }

    private fun openWallet(call: MethodCall, result: MethodChannel.Result) {
        val keystore = call.argument<String>("keystore") ?: null
        val password = call.argument<String>("password") ?: ""
        val config = WalletConfig()
        config.password = password;
        try {
            val wallet = Nkn.walletFromJSON(keystore, config)
            val json = wallet?.toJSON()
            var data = hashMapOf(
                    "address" to wallet.address(),
                    "keystore" to json,
                    "publicKey" to wallet.pubKey().toHex(),
                    "seed" to wallet.seed().toHex()
            )
            result.success(data)
        }catch (e : Exception){
            result.error("0", e.localizedMessage, "")
        }
    }

    private fun transfer(call: MethodCall, result: MethodChannel.Result) {
        val keystore = call.argument<String>("keystore") ?: null
        val password = call.argument<String>("password") ?: ""
        val address = call.argument<String>("address") ?: null
        val amount = call.argument<String>("amount") ?: null
        val fee = call.argument<String>("fee") ?: null
        val config = WalletConfig()
        config.password = password;
        val wallet = Nkn.walletFromJSON(keystore, config)

        val transactionConfig = TransactionConfig()
        transactionConfig.fee = fee
        val hash = wallet.transfer(address, amount, transactionConfig)
        result.success(hash)
    }

    private fun transferAsync(call: MethodCall, result: MethodChannel.Result) {
        val keystore = call.argument<String>("keystore") ?: null
        val password = call.argument<String>("password") ?: ""
        val address = call.argument<String>("address") ?: null
        val _id = call.argument<String>("_id") ?: null
        val amount = call.argument<String>("amount") ?: null
        val fee = call.argument<String>("fee") ?: null
        val config = WalletConfig()
        config.password = password;
        result.success(null)
        AsyncTask.SERIAL_EXECUTOR.execute {
            try {
                val wallet = Nkn.walletFromJSON(keystore, config)
                val transactionConfig = TransactionConfig()
                transactionConfig.fee = fee
                val hash = wallet.transfer(address, amount, transactionConfig)
                App.runOnMainThread {
                    var hash = hashMapOf(
                            "_id" to _id,
                            "result" to hash
                    )
                    walletEventSink?.success(hash)
                }
            }
            catch (e : Exception){
                App.runOnMainThread {
                    walletEventSink?.error(_id,"","")
                }

            }
        }
    }

    private fun getBalanceAsync(call: MethodCall, result: MethodChannel.Result) {
        val _id = call.argument<String>("_id") ?: null
        val address = call.argument<String>("address") ?: null
        val account = Nkn.newAccount(Nkn.randomBytes(32))
        val config = WalletConfig()
        val wallet = Nkn.newWallet(account, config)
        result.success(null)
        AsyncTask.SERIAL_EXECUTOR.execute {
           try {
               val balance = wallet.balanceByAddress(address).toString()
               App.runOnMainThread {
                   var hash = hashMapOf(
                           "_id" to _id,
                           "result" to balance.toDouble()
                   )
                   walletEventSink?.success(hash)
               }
           }catch (e : Exception){
               App.runOnMainThread {
                   walletEventSink?.error(_id,"","")
               }

           }
        }
    }


    private fun getBalance(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address") ?: null
        val account = Nkn.newAccount(Nkn.randomBytes(32))
        val config = WalletConfig()
        val wallet = Nkn.newWallet(account, config)
        try {
            val balance = wallet.balanceByAddress(address).toString()
            result.success(balance.toString())
        } catch (e: Exception) {
            result.error("1", e.localizedMessage, "")
        }
    }

    private fun restoreWallet(call: MethodCall, result: MethodChannel.Result) {
        val keystore = call.argument<String>("keystore") ?: null
        val password = call.argument<String>("password") ?: ""
        val config = WalletConfig()
        config.password = password
        val wallet = Nkn.walletFromJSON(keystore, config)
        val json = wallet?.toJSON()
        result.success(json)
    }

    private fun createWallet(call: MethodCall, result: MethodChannel.Result) {
        var seedHex = call.argument<String>("seed");
        val password = call.argument<String>("password");
        val seed = seedHex?.decodeHex() ?: Nkn.randomBytes(32)
        val account = Nkn.newAccount(seed)
        val config = WalletConfig()
        config.password = password
        val wallet = Nkn.newWallet(account, config)
        val keystore = wallet.toJSON()
        result.success(keystore)
    }

    private fun fetchDebugInfo(call: MethodCall, result: MethodChannel.Result){
        Log.e("222:","HereHere")
        val ks: KeyStore = KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        val aliases: Enumeration<String> = ks.aliases()

        var keyStoreAliases:String = ""
        while (aliases.hasMoreElements()){
            val alias:String = aliases.nextElement()
            keyStoreAliases = keyStoreAliases+alias
        }
        Log.e("111:"+keyStoreAliases,"keyStoreAliases:"+keyStoreAliases)

        result.success(keyStoreAliases)
    }
}