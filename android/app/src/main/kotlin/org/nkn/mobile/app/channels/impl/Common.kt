package org.nkn.mobile.app.channels.impl

import android.app.Activity
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.nkn.mobile.app.channels.IChannelHandler
import org.nkn.mobile.app.push.APNSPush
import reedsolomon.BytesArray
import reedsolomon.Encoder
import reedsolomon.Reedsolomon
import kotlin.text.Charsets.UTF_8

class Common(private var activity: Activity) : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {

    companion object {
        lateinit var methodChannel: MethodChannel
        var eventSink: EventChannel.EventSink? = null
        val CHANNEL_NAME = "org.nkn.mobile/native/common"

        fun register(activity: Activity, flutterEngine: FlutterEngine) {
            Common(activity).install(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

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
            "backDesktop" -> {
                backDesktop(call, result)
            }
            "sendPushAPNS" -> {
                sendPushAPNS(call, result)
            }
            "isGoogleServiceAvailable" -> {
                isGoogleServiceAvailable(call, result)
            }
            "splitPieces" -> {
                splitPieces(call, result)
            }
            "combinePieces" -> {
                combinePieces(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun backDesktop(call: MethodCall, result: MethodChannel.Result) {
        this.activity.moveTaskToBack(false)
        result.success(true)
    }

    private fun sendPushAPNS(call: MethodCall, result: MethodChannel.Result) {
        val deviceToken = call.argument<String>("deviceToken")!!
        val pushPayload = call.argument<String>("pushPayload")!!

        viewModelScope.launch(Dispatchers.IO) {
            APNSPush.push(activity.assets, deviceToken, pushPayload)
            try {
                val resp = hashMapOf(
                    "event" to "sendPushAPNS",
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun isGoogleServiceAvailable(call: MethodCall, result: MethodChannel.Result) {
        viewModelScope.launch(Dispatchers.IO) {
            val code = GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(activity)
            val availability = if (code == ConnectionResult.SUCCESS) {
                Log.e("GoogleServiceCheck", "success")
                true
            } else {
                Log.e("GoogleServiceCheck", "code:$code")
                false
            }
            try {
                val resp = hashMapOf(
                    "event" to "isGoogleServiceAvailable",
                    "availability" to availability,
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun splitPieces(call: MethodCall, result: MethodChannel.Result) {
        val dataString = call.argument<String>("data")!!
        val dataShards = call.argument<Int>("dataShards")!!
        val parityShards = call.argument<Int>("parityShards")!!

        viewModelScope.launch(Dispatchers.IO) {
            val encoder: Encoder? = Reedsolomon.newDefault(dataShards.toLong(), parityShards.toLong())
            val splitBytes: BytesArray? = encoder?.splitBytesArray(dataString.toByteArray())
            encoder?.encodeBytesArray(splitBytes)

            val returnArray = ArrayList<ByteArray>()
            if (splitBytes != null && splitBytes.len() > 0) {
                for (index: Int in 0 until (dataShards + parityShards)) {
                    if (index >= splitBytes.len()) break
                    val b = splitBytes.get(index.toLong())
                    if (b != null) returnArray.add(b)
                }
            }

            try {
                val resp = hashMapOf(
                    "event" to "splitPieces",
                    "data" to returnArray,
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun combinePieces(call: MethodCall, result: MethodChannel.Result) {
        val dataList = call.argument<ArrayList<ByteArray>>("data")!!
        val dataShards = call.argument<Int>("dataShards")!!
        val parityShards = call.argument<Int>("parityShards")!!
        val bytesLength = call.argument<Int>("bytesLength")!!

        viewModelScope.launch(Dispatchers.IO) {
            val totalShards = dataShards + parityShards
            val encodeDataBytes = BytesArray(totalShards.toLong())
            var piecesLength = 0
            for (index in dataList.indices) {
                val data = dataList[index]
                piecesLength += data.size
                if (data.isNotEmpty()) {
                    encodeDataBytes[index.toLong()] = data
                } else {
                    encodeDataBytes[index.toLong()] = null
                }
            }

            val encoder = Reedsolomon.newDefault(dataShards.toLong(), parityShards.toLong())
            try {
                encoder.reconstructBytesArray(encodeDataBytes)
                val ok = encoder.verifyBytesArray(encodeDataBytes)
                if (!ok) Log.e("combinePieces", "verifyBytesArray == false")
            } catch (e: Exception) {
                Log.e("combinePieces", "reconstructBytesArrayE:" + e.localizedMessage)
                resultError(result, e)
                return@launch
            }

            val fullDataList = ByteArray(piecesLength)
            var copyIndex = 0
            for (index in 0 until dataShards) {
                val data = encodeDataBytes[index.toLong()]
                val dataSize = data?.size ?: 0
                System.arraycopy(data, 0, fullDataList, copyIndex, dataSize)
                copyIndex += dataSize
            }

            val resultBytes = ByteArray(bytesLength)
            val resultLength = if (fullDataList.size > bytesLength) bytesLength else fullDataList.size
            System.arraycopy(fullDataList, 0, resultBytes, 0, resultLength)

            if (resultBytes.isEmpty()) {
                Log.e("combinePieces", "resultByte.size == 0")
                resultError(result, Error("resultByte.size == 0"))
                return@launch
            }

            val combines = String(resultBytes, UTF_8)

            try {
                val resp = hashMapOf(
                    "event" to "combinePieces",
                    "data" to combines,
                )
                resultSuccess(result, resp)
            } catch (e: Exception) {
                resultError(result, e)
                return@launch
            }
        }
    }
}