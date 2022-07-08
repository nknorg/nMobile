package org.nkn.sdk.impl

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.nkn.sdk.IChannelHandler

class Crypto : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {
    companion object {
        val CHANNEL_NAME = "org.nkn.sdk/crypto"
        val EVENT_NAME = "org.nkn.sdk/crypto/event"
    }

    lateinit var channel: MethodChannel
    var eventSink: EventChannel.EventSink? = null

    override fun install(binaryMessenger: BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun uninstall() {
        channel.setMethodCallHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPublicKeyFromPrivateKey" -> {
                getPublicKeyFromPrivateKey(call, result)
            }
            "getPrivateKeyFromSeed" -> {
                getPrivateKeyFromSeed(call, result)
            }
            "getSeedFromPrivateKey" -> {
                getSeedFromPrivateKey(call, result)
            }
            "sign" -> {
                sign(call, result)
            }
            "verify" -> {
                // verify(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getPublicKeyFromPrivateKey(call: MethodCall, result: MethodChannel.Result) {
        val privateKey = call.argument<ByteArray>("privateKey")
        val publicKey = crypto.Crypto.getPublicKeyFromPrivateKey(privateKey)
        result.success(publicKey)
    }

    private fun getPrivateKeyFromSeed(call: MethodCall, result: MethodChannel.Result) {
        val seed = call.argument<ByteArray>("seed")
        val privateKey = crypto.Crypto.getPrivateKeyFromSeed(seed)
        result.success(privateKey)
    }

    private fun getSeedFromPrivateKey(call: MethodCall, result: MethodChannel.Result) {
        val privateKey = call.argument<ByteArray>("privateKey")
        val seed = crypto.Crypto.getSeedFromPrivateKey(privateKey)
        result.success(seed)
    }

    private fun sign(call: MethodCall, result: MethodChannel.Result) {
        val privateKey = call.argument<ByteArray>("privateKey")
        val data = call.argument<ByteArray>("data")
        try {
            val signature = crypto.Crypto.sign(privateKey, data)
            result.success(signature)
        } catch (e: Throwable) {
            result.error("", e.localizedMessage, e.message)
        }
    }
}