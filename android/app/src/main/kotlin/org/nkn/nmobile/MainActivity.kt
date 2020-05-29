package org.nkn.nmobile

import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import nkn.Nkn
import nkn.WalletConfig

class MainActivity: FlutterActivity() {

    private val N_MOBILE_NATIVE = "android/nmbile/native/common"


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
//        GeneratedPluginRegistrant.registerWith(flutterEngine)


        MethodChannel(flutterEngine.dartExecutor, "org.nkn.sdk/wallet").
                setMethodCallHandler(NknWalletPlugin());


        EventChannel(flutterEngine.dartExecutor, "org.nkn.sdk/wallet/event").setStreamHandler(NknWalletEventPlugin())


        MethodChannel(flutterEngine.dartExecutor, "org.nkn.sdk/client").
                setMethodCallHandler(NknClientPlugin());

        EventChannel(flutterEngine.dartExecutor, "org.nkn.sdk/client/event").setStreamHandler(NknClientEventPlugin())


        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_NATIVE).setMethodCallHandler { methodCall, result ->
            if (methodCall.method == "backDesktop") {
                result.success(true)
                moveTaskToBack(false)
            }else{
                result.success(true)
            }

        }

    }

    override fun onResume() {
        super.onResume()
    }
}
