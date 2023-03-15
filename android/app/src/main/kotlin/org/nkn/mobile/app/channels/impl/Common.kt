package org.nkn.mobile.app.channels.impl

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Environment.DIRECTORY_PICTURES
import android.os.Handler
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.nkn.mobile.app.MainActivity
import org.nkn.mobile.app.channels.IChannelHandler
import org.nkn.mobile.app.push.APNSPush
import reedsolomon.BytesArray
import reedsolomon.Encoder
import reedsolomon.Reedsolomon
import java.io.File
import java.io.FileOutputStream
import kotlin.text.Charsets.UTF_8

class Common : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {

    companion object {
        lateinit var methodChannel: MethodChannel
        const val METHOD_CHANNEL_NAME = "org.nkn.mobile/native/common_method"

        lateinit var eventChannel: EventChannel
        const val EVENT_CHANNEL_NAME = "org.nkn.mobile/native/common_event"
        private var eventSink: EventChannel.EventSink? = null

        fun register(flutterEngine: FlutterEngine) {
            Common().install(flutterEngine.dartExecutor.binaryMessenger)
        }

        fun eventAdd(name: String, map: HashMap<String, *>) {
            val resultMap = hashMapOf<String, Any>()
            resultMap["event"] = name
            resultMap.putAll(map)
            Handler(MainActivity.instance.mainLooper).post { eventSink?.success(resultMap) }
        }

        fun eventAdd(name: String, result: Any) {
            val resultMap = hashMapOf<String, Any>()
            resultMap["event"] = name
            resultMap["result"] = result
            Handler(MainActivity.instance.mainLooper).post { eventSink?.success(resultMap) }
        }

        fun isApplicationForeground(context: Context): Boolean {
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            if (keyguardManager != null && keyguardManager.isKeyguardLocked) {
                return false
            }
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
            val appProcesses = activityManager.runningAppProcesses ?: return false
            val packageName = context.packageName
            for (appProcess in appProcesses) {
                if (appProcess.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND && appProcess.processName == packageName) {
                    return true
                }
            }
            return false
        }
    }

    override fun install(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binaryMessenger, EVENT_CHANNEL_NAME)
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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "backDesktop" -> {
                backDesktop(call, result)
            }
            "saveImageToGallery" -> {
                saveImageToGallery(call, result)
            }
            "sendPushAPNS" -> {
                sendPushAPNS(call, result)
            }
            //"isGoogleServiceAvailable" -> {
            //    isGoogleServiceAvailable(call, result)
            //}
            "getFCMToken" -> {
                getFCMToken(call, result)
            }
            //"encryptBytes" -> {
            //    encryptBytes(call, result)
            //}
            //"decryptBytes" -> {
            //    decryptBytes(call, result)
            //}
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
        MainActivity.instance.moveTaskToBack(false)
        result.success(true)
    }

    private fun saveImageToGallery(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("imageData")!!
        val imageName = call.argument<String>("imageName")!!
        val albumName = call.argument<String>("albumName")!!

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val parentDir = File(Environment.getExternalStoragePublicDirectory(DIRECTORY_PICTURES), albumName)
                // val parentDir = File(MainActivity.instance.getExternalFilesDir(Environment.DIRECTORY_PICTURES), albumName)
                if (!parentDir.exists()) {
                    parentDir.mkdir()
                }

                val file = File(parentDir, imageName)
                val fos = FileOutputStream(file)
                fos.write(data)
                fos.close()

                MainActivity.instance.sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(file.absoluteFile)))
                // MediaScannerConnection.scanFile(MainActivity.instance, arrayOf(file.absolutePath), null, null)

                val resp = hashMapOf(
                    "event" to "saveImageToGallery",
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    private fun sendPushAPNS(call: MethodCall, result: MethodChannel.Result) {
        val uuid = call.argument<String>("uuid")!!
        val deviceToken = call.argument<String>("deviceToken")!!
        val topic = call.argument<String>("topic")!!
        val pushPayload = call.argument<String>("pushPayload")!!

        viewModelScope.launch(Dispatchers.IO) {
            try {
                APNSPush.push(MainActivity.instance.assets, uuid, deviceToken, topic, pushPayload, {
                    val resp = hashMapOf(
                        "event" to "sendPushAPNS",
                    )
                    viewModelScope.launch(Dispatchers.IO) {
                        resultSuccess(result, resp)
                    }
                    return@push
                }, { errCode: Int?, errMsg: String? ->
                    val resp = hashMapOf(
                        "event" to "sendPushAPNS",
                        "errCode" to errCode,
                        "errMsg" to errMsg,
                    )
                    viewModelScope.launch(Dispatchers.IO) {
                        resultSuccess(result, resp)
                    }
                    return@push
                })
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    /*private fun isGoogleServiceAvailable(call: MethodCall, result: MethodChannel.Result) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val code = GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(MainActivity.instance)
                val availability = if (code == ConnectionResult.SUCCESS) {
                    Log.i("GoogleServiceCheck", "success")
                    true
                } else {
                    Log.i("GoogleServiceCheck", "code:$code")
                    false
                }
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
    }*/

    @SuppressLint("CommitPrefEdits")
    private fun getFCMToken(call: MethodCall, result: MethodChannel.Result) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val sharedPreferences = MainActivity.instance.getSharedPreferences("fcmToken", Context.MODE_PRIVATE)
                val deviceToken = sharedPreferences.getString("token", null)
                val resp = hashMapOf(
                    "event" to "getFCMToken",
                    "token" to deviceToken,
                )
                resultSuccess(result, resp)
                return@launch
                /*if (!deviceToken.isNullOrEmpty()) {
                    val resp = hashMapOf(
                        "event" to "getFCMToken",
                        "token" to deviceToken,
                    )
                    resultSuccess(result, resp)
                    return@launch
                } else {
                    val code = GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(MainActivity.instance)
                    if (code != ConnectionResult.SUCCESS) {
                        val resp = hashMapOf(
                            "event" to "getFCMToken",
                            "token" to null,
                        )
                        resultSuccess(result, resp)
                        return@launch
                    }
                    val task = FirebaseMessaging.getInstance().token
                    task.addOnSuccessListener { fetchToken ->
                        sharedPreferences.edit().putString("token", fetchToken).apply()
                        val resp = hashMapOf(
                            "event" to "getFCMToken",
                            "token" to fetchToken,
                        )
                        viewModelScope.launch(Dispatchers.IO) {
                            resultSuccess(result, resp)
                        }
                        return@addOnSuccessListener
                    }.addOnCanceledListener {
                        val resp = hashMapOf(
                            "event" to "getFCMToken",
                            "token" to null,
                        )
                        viewModelScope.launch(Dispatchers.IO) {
                            resultSuccess(result, resp)
                        }
                        return@addOnCanceledListener
                    }.addOnFailureListener {
                        val resp = hashMapOf(
                            "event" to "getFCMToken",
                            "token" to null,
                        )
                        viewModelScope.launch(Dispatchers.IO) {
                            resultSuccess(result, resp)
                        }
                        return@addOnFailureListener
                    }
                }*/
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }

    /*private fun encryptBytes(call: MethodCall, result: MethodChannel.Result) {
        val algorithm = call.argument<String>("algorithm")!!
        val bits = call.argument<Int>("bits")!!
        val data = call.argument<ByteArray>("data")!!

        viewModelScope.launch(Dispatchers.IO) {
            val encrypted = Encrypt.encrypt(algorithm, bits, data)
            try {
                val resp = hashMapOf(
                    "event" to "encryptBytes",
                    "data" to encrypted,
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }*/

    /*private fun decryptBytes(call: MethodCall, result: MethodChannel.Result) {
        val algorithm = call.argument<String>("algorithm")!!
        val bits = call.argument<Int>("bits")!!
        val keyBytes = call.argument<ByteArray>("key_bytes")!!
        val ivBytes = call.argument<ByteArray>("iv_bytes")!!
        val data = call.argument<ByteArray>("data")!!

        viewModelScope.launch(Dispatchers.IO) {
            val decrypted = Encrypt.decrypt(algorithm, bits, keyBytes, ivBytes, data)
            try {
                val resp = hashMapOf(
                    "event" to "decryptBytes",
                    "data" to decrypted,
                )
                resultSuccess(result, resp)
                return@launch
            } catch (e: Throwable) {
                resultError(result, e)
                return@launch
            }
        }
    }*/

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
            val encodeDataBytes = BytesArray((dataShards + parityShards).toLong())
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
                Log.e("combinePieces", "reconstructBytesArray:" + e.localizedMessage)
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