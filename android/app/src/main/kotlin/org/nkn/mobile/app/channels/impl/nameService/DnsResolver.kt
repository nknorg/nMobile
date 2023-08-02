package org.nkn.mobile.app.channels.impl.nameService

import androidx.lifecycle.ViewModel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.nkn.mobile.app.channels.IChannelHandler


class DnsResolver : IChannelHandler, MethodChannel.MethodCallHandler, ViewModel() {
    companion object {
        lateinit var methodChannel: MethodChannel
        const val METHOD_CHANNEL_NAME = "org.nkn.mobile/native/nameservice/dnsresolver"

        fun register(flutterEngine: FlutterEngine) {
            DnsResolver().install(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun install(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
    }

    override fun uninstall() {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "resolve" -> resolve(call, result)
            else -> result.notImplemented()
        }
    }

    private fun resolve(call: MethodCall, result: MethodChannel.Result) {
//        val config = call.argument<Map<String, Any>>("config") ?: mapOf()
//        val address = call.argument<String>("address") ?: ""
//        val dnsResolverConfig: dnsresolver.Config = dnsresolver.Config()
//        dnsResolverConfig.dnsServer = config["dnsServer"] as? String ?: ""
//        val dnsresolver: dnsresolver.Resolver = dnsresolver.Resolver(dnsResolverConfig)
//        val res = dnsresolver.resolve(address)
//        result.success(res)
    }
}