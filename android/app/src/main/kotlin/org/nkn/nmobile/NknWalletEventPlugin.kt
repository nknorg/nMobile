package org.nkn.nmobile

import io.flutter.plugin.common.EventChannel

class NknWalletEventPlugin: EventChannel.StreamHandler {

    companion object{
        var walletEventSink: EventChannel.EventSink? = null
    }


    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        walletEventSink = events
    }

    override fun onCancel(arguments: Any?) {
    }

}