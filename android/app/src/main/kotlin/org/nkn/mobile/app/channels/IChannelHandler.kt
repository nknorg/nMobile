package org.nkn.mobile.app.channels

import androidx.annotation.NonNull
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

interface IChannelHandler {
    fun install(@NonNull binaryMessenger: BinaryMessenger)
    fun uninstall()

    suspend fun resultSuccess(result: MethodChannel.Result, resp: Any?) = withContext(Dispatchers.Main) {
        result.success(resp)
    }

    suspend fun resultError(result: MethodChannel.Result, error: Throwable) = withContext(Dispatchers.Main) {
        result.error("", error.localizedMessage, error.message)
    }

    suspend fun resultError(result: MethodChannel.Result, code: String? = "", message: String? = "", details: String? = "") = withContext(Dispatchers.Main) {
        result.error(code, message, details)
    }

    suspend fun eventSinkSuccess(eventSink: EventChannel.EventSink?, resp: Any?) = withContext(Dispatchers.Main) {
        eventSink?.success(resp)
    }

    suspend fun eventSinkError(eventSink: EventChannel.EventSink?, error: Throwable) = withContext(Dispatchers.Main) {
        eventSink?.error("", error.localizedMessage, error.message)
    }

    suspend fun eventSinkError(eventSink: EventChannel.EventSink?, code: String? = "", message: String? = "", details: String? = "") = withContext(Dispatchers.Main) {
        eventSink?.error(code, message, details)
    }
}