package org.nkn.nmobile

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NknClientEventPlugin : EventChannel.StreamHandler {

    companion object {
        var clientEventSink: EventChannel.EventSink? = null
    }


    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        clientEventSink = events
    }

    override fun onCancel(arguments: Any?) {
    }

}