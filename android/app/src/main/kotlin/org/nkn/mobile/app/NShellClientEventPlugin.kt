package org.nkn.mobile.app

import io.flutter.plugin.common.EventChannel

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