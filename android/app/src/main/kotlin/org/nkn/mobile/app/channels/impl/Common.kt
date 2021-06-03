package org.nkn.mobile.app.channels.impl

import android.app.Activity
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.nkn.mobile.app.channels.IChannelHandler
import reedsolomon.BytesArray
import reedsolomon.Encoder
import reedsolomon.Reedsolomon
import kotlin.text.Charsets.UTF_8

class Common(private var activity: Activity) : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {

    companion object {
        lateinit var methodChannel: MethodChannel
        var eventSink: EventChannel.EventSink? = null
        val CHANNEL_NAME = "org.nkn.mobile/native/common"
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

    private fun splitPieces(call: MethodCall, result: MethodChannel.Result) {
        val flutterDataString = call.argument<String>("data")!!
        val dataShards = call.argument<Int>("dataShards")!!
        val parityShards = call.argument<Int>("parityShards")!!

        val encoder: Encoder? = Reedsolomon.newDefault(dataShards.toLong(), parityShards.toLong())
        val dataBytes: BytesArray? = encoder?.splitBytesArray(flutterDataString.toByteArray())

        encoder?.encodeBytesArray(dataBytes)

        val dataBytesArray = ArrayList<ByteArray>()

        val totalPieces: Int = dataShards + parityShards - 1
        for (index: Int in 0..totalPieces) {
            val theBytes = dataBytes?.get(index.toLong())
            if (theBytes != null) {
                dataBytesArray.add(theBytes)
            }
        }
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val resp = hashMapOf(
                    "event" to "intoPieces",
                    "data" to dataBytesArray,
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
        val fDataList = call.argument<ArrayList<ByteArray>>("data")!!
        val dataShards = call.argument<Int>("dataShards")!!
        val parityShards = call.argument<Int>("parityShards")!!
        val bytesLength = call.argument<Int>("bytesLength")!!

        val combines: String? = combineBytesArray(fDataList, dataShards, parityShards, bytesLength)

        viewModelScope.launch(Dispatchers.IO) {
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

    private fun combineBytesArray(fDataList: java.util.ArrayList<ByteArray>, dataShards: Int, parityShards: Int, totalLength: Int): String? {
        val encoder = Reedsolomon.newDefault(dataShards.toLong(), parityShards.toLong())
        val totalShards = dataShards + parityShards
        val encodeDataBytes = BytesArray(totalShards.toLong())

        var pieceLength = 0
        for (index in fDataList.indices) {
            val fDatas = fDataList[index]
            if (fDatas.isNotEmpty()) {
                pieceLength = fDatas.size
                break
            }
        }

        for (index in fDataList.indices) {
            val fDatas = fDataList[index]
            if (fDatas.isNotEmpty()) {
                encodeDataBytes[index.toLong()] = fDatas
            } else {
                encodeDataBytes[index.toLong()] = null
            }
        }

        try {
            encoder.reconstructBytesArray(encodeDataBytes)
        } catch (e: Exception) {
            Log.e("combineBytesArray", "reconstructBytesArrayE:" + e.localizedMessage)
            return null
        }

        val fullDataBytes = ByteArray(dataShards * pieceLength)
        var copyIndex = 0
        for (index in 0 until dataShards) {
            val dataBytes = encodeDataBytes[index.toLong()]
            System.arraycopy(dataBytes, 0, fullDataBytes, copyIndex, dataBytes.size)
            copyIndex += dataBytes.size
        }

        val resultBytes = ByteArray(totalLength)
        if (fullDataBytes.size > totalLength) {
            System.arraycopy(fullDataBytes, 0, resultBytes, 0, totalLength)
        } else {
            System.arraycopy(fullDataBytes, 0, resultBytes, 0, totalLength)
        }

        if (resultBytes.isEmpty()) {
            Log.e("combineBytesArray", "resultByte Length is 0")
            return null
        }
        return String(resultBytes, UTF_8)
    }
}