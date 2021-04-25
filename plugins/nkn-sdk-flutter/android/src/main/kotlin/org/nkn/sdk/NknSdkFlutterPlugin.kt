package org.nkn.sdk

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import org.nkn.sdk.impl.Client
import org.nkn.sdk.impl.Common
import org.nkn.sdk.impl.Wallet


/** NknSdkFlutterPlugin */
class NknSdkFlutterPlugin : FlutterPlugin {
    companion object {
        const val TAG = "nkn-sdk-flutter"
    }

    private val common: Common = Common()
    private val wallet: Wallet = Wallet()
    private val client: Client = Client()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        common.install(flutterPluginBinding.binaryMessenger)
        wallet.install(flutterPluginBinding.binaryMessenger)
        client.install(flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        common.uninstall()
        wallet.uninstall()
        client.uninstall()
    }
}
