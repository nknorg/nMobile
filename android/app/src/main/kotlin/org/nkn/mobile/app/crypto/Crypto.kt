package org.nkn.mobile.app.crypto

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.nkn.sdk.IChannelHandler

class Crypto : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {
    companion object {
        const val METHOD_CHANNEL_NAME = "org.nkn.mobile/native/crypto_method"
        const val EVENT_CHANNEL_NAME = "org.nkn.mobile/native/crypto_event"

        fun register(flutterEngine: FlutterEngine) {
            Crypto().install(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    lateinit var channel: MethodChannel
    var eventSink: EventChannel.EventSink? = null

    override fun install(binaryMessenger: BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, METHOD_CHANNEL_NAME)
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
            "gcmEncrypt" -> {
                gcmEncrypt(call, result)
            }
            "gcmDecrypt" -> {
                gcmDecrypt(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun gcmEncrypt(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data")!!
        val key = call.argument<ByteArray>("key")!!
        val nonceSize = call.argument<Int>("nonceSize") ?: 0

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val cipherText = crypto.Crypto.gcmEncrypt(data, key, nonceSize.toLong())
                resultSuccess(result, cipherText)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun gcmDecrypt(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data")!!
        val key = call.argument<ByteArray>("key")!!
        val nonceSize = call.argument<Int>("nonceSize") ?: 0

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val plainTex = crypto.Crypto.gcmDecrypt(data, key, nonceSize.toLong())
                resultSuccess(result, plainTex)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

}