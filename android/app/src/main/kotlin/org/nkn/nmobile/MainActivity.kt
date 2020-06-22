package org.nkn.nmobile

import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import nkn.Nkn
import nkn.WalletConfig
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix
import org.nkn.nmobile.app.util.Tag
import java.util.*

class MainActivity : FlutterFragmentActivity(), Tag {
    private val TAG by lazy { tag() }

    companion object {
        private const val N_MOBILE_NATIVE = "android/nmobile/native/common"
        private const val N_MOBILE_SDK_WALLET = "org.nkn.sdk/wallet"
        private const val N_MOBILE_SDK_WALLET_EVENT = "org.nkn.sdk/wallet/event"
        private const val N_MOBILE_SDK_CLIENT = "org.nkn.sdk/client"
        private const val N_MOBILE_SDK_CLIENT_EVENT = "org.nkn.sdk/client/event"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.e(TAG, "<<<---configureFlutterEngine--->>>".withAndroidPrefix())

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_WALLET).setMethodCallHandler(NknWalletPlugin());
        EventChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_WALLET_EVENT).setStreamHandler(NknWalletEventPlugin())
        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_CLIENT).setMethodCallHandler(NknClientPlugin());
        EventChannel(flutterEngine.dartExecutor, N_MOBILE_SDK_CLIENT_EVENT).setStreamHandler(NknClientEventPlugin())
        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_NATIVE).setMethodCallHandler { methodCall, result ->
            if (methodCall.method == "backDesktop") {
                result.success(true)
                moveTaskToBack(false)
            } else {
                result.success(true)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.e(TAG, "<<<---onCreate--->>>".withAndroidPrefix())
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "<<<---onStart--->>>".withAndroidPrefix())
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "<<<---onResume--->>>".withAndroidPrefix())
    }

    override fun onPause() {
        Log.d(TAG, ">>>---onPause---<<<".withAndroidPrefix())
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.d(TAG, ">>>---onSaveInstanceState---<<<".withAndroidPrefix())
        // e.g:
        val bundle = Bundle()
        bundle.putString("key", "value")
        outState.putParcelable("app:$TAG", bundle)
        outState.putString("app:${TAG.toLowerCase(Locale.US)}:key", "value")
    }

    override fun onStop() {
        Log.d(TAG, ">>>---onStop---<<<".withAndroidPrefix())
        super.onStop()
    }

    override fun onDestroy() {
        Log.e(TAG, ">>>---onDestroy---<<<".withAndroidPrefix())
        super.onDestroy()
    }
}
