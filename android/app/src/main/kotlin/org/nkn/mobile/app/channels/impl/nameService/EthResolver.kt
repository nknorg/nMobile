package org.nkn.mobile.app.channels.impl.nameService

import androidx.lifecycle.ViewModel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.nkn.mobile.app.channels.IChannelHandler


class EthResolver : IChannelHandler, MethodChannel.MethodCallHandler, ViewModel() {
    companion object {
        lateinit var methodChannel: MethodChannel
        const val METHOD_CHANNEL_NAME = "org.nkn.mobile/native/nameservice/ethresolver"

        fun register(flutterEngine: FlutterEngine) {
            EthResolver().install(flutterEngine.dartExecutor.binaryMessenger)
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
            "resolve" -> {
                resolve(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun resolve(call: MethodCall, result: MethodChannel.Result) {
        val config = call.argument<Map<String, Any>>("config")!!
        val address = call.argument<String>("address")
        val ethResolverConfig: ethresolver.Config = ethresolver.Config()
        ethResolverConfig.prefix = config["prefix"] as String?
        ethResolverConfig.rpcServer = config["rpcServer"] as String?
        ethResolverConfig.contractAddress = config["contractAddress"] as String?
        val ethResolver: ethresolver.Resolver = ethresolver.Resolver(ethResolverConfig)
        val res = ethResolver.resolve(address)
        result.success(res)
    }
}