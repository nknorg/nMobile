package org.nkn.mobile.app.channels.impl

import android.app.Activity
import androidx.lifecycle.ViewModel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.nkn.mobile.app.channels.IChannelHandler

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
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun backDesktop(call: MethodCall, result: MethodChannel.Result) {
        this.activity.moveTaskToBack(false)
        result.success(true)
    }

}