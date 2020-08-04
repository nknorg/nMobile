package org.nkn.mobile.app

import android.os.*
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import nkn.Account
import nkn.Nkn
import nkn.WalletConfig
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix
import org.nkn.mobile.app.abs.Tag
import java.util.*
import org.nkn.mobile.app.dchat.*
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity(), Tag {
    val TAG by lazy { tag() }

    companion object {
        private const val N_MOBILE_NATIVE = "android/nmobile/native/common"
    }

    /*private */var clientPlugin: NknClientPlugin? = null
    private var isActive : Boolean =  false;

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.e(TAG, "<<<---configureFlutterEngine--->>>".withAndroidPrefix())

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        NknWalletPlugin(flutterEngine)
        clientPlugin = NknClientPlugin(this, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor, "org.nkn.sdk/nshellclient").setMethodCallHandler(NShellClientPlugin())
        EventChannel(flutterEngine.dartExecutor, "org.nkn.sdk/nshellclient/event").setStreamHandler(NShellClientEventPlugin())
        MethodChannel(flutterEngine.dartExecutor, "org.nkn.native.call/apk_installer").setMethodCallHandler(InstallApkMethodPlugin())

        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_NATIVE).setMethodCallHandler { methodCall, result ->
            if (methodCall.method == "backDesktop") {
                result.success(true)
                moveTaskToBack(false)
            }else if (methodCall.method == "isActive") {
                result.success(isActive)
            } else {
                result.success(true)
            }
        }
        MessagingServiceFlutterPlugin.config(flutterEngine)
    }

    fun onClientCreated() {
        App.get().onUiClientCreated()
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
        isActive = true;
    }

    override fun onPause() {
        Log.d(TAG, ">>>---onPause---<<<".withAndroidPrefix())
        super.onPause()
        isActive = false;
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
        isActive = false;
    }

    override fun onDestroy() {
        clientPlugin?.close()
        Log.e(TAG, ">>>---onDestroy---<<<".withAndroidPrefix())
        super.onDestroy()
    }
}
