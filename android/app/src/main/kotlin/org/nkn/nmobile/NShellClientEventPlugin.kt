package org.nkn.nmobile

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NShellClientEventPlugin : EventChannel.StreamHandler {

    companion object {
        var nshellClientEventSink: EventChannel.EventSink? = null
    }


    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        nshellClientEventSink = events
    }

    override fun onCancel(arguments: Any?) {
    }

}