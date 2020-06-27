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
import org.nkn.mobile.app.dchat.Msgs
import java.util.*
import hobby.wei.c.core.AbsMsgrActy
import hobby.wei.c.core.AbsMsgrService
import org.nkn.mobile.app.abs.StartMe
import org.nkn.mobile.app.dchat.*

class MainActivity : AbsMsgrActy(), Msgs.Req, Msgs.Req.Callback, Tag {
    override val serviceStarter: StartMe.MsgrSrvce
        get() = DChatServiceForFlutter.Starter
    override val msgrServiceClazz: Class<out AbsMsgrService>
        get() = DChatServiceForFlutter::class.java

    override fun handleServerMsg(msg: Message, handler: Handler) {
        if (!handleServerMsg(msg, handler, this)) {
            super<AbsMsgrActy>.handleServerMsg(msg, handler)
        }
    }

    companion object {
        private const val N_MOBILE_NATIVE = "android/nmobile/native/common"
    }

    private var clientPlugin: NknClientPlugin? = null
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.e(TAG, "<<<---configureFlutterEngine--->>>".withAndroidPrefix())

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        NknWalletPlugin(flutterEngine)
        clientPlugin = NknClientPlugin(this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_NATIVE).setMethodCallHandler { methodCall, result ->
            if (methodCall.method == "backDesktop") {
                result.success(true)
                moveTaskToBack(false)
            } else {
                result.success(true)
            }
        }
        MessagingServiceFlutterPlugin.config(flutterEngine)
    }

    fun sendAccount2Service(account: Account?) {
        Log.w(TAG, "<<<---sendAccount2Service--->>>".withAndroidPrefix())
        sendMsg2Server(buildMsg4SendAccount(account))
    }

    override fun onConnectionChanged(connected: Boolean) {
        Log.d(TAG, "<<<---onConnectionChanged--->>>".withAndroidPrefix())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.e(TAG, "<<<---onCreate--->>>".withAndroidPrefix())
        tryOrRebind()
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
        ensureUnbind()
        clientPlugin?.close()
        Log.e(TAG, ">>>---onDestroy---<<<".withAndroidPrefix())
        super.onDestroy()
    }
}
