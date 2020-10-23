package org.nkn.mobile.app

import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import io.sentry.Sentry
import io.sentry.android.AndroidSentryClientFactory
import org.nkn.mobile.app.abs.Tag
import org.nkn.mobile.app.dchat.MessagingServiceFlutterPlugin
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix
import java.util.*

class MainActivity : FlutterFragmentActivity(), Tag {
    val TAG by lazy { tag() }

    val instance by lazy { this } //这里使用了委托，表示只有使用到instance才会执行该段代码

    companion object {
        private const val N_MOBILE_COMMON = "org.nkn.nmobile/native/common"
    }

    /*private */var clientPlugin: NknClientPlugin? = null
    private var isActive : Boolean =  false;
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.e(TAG, "<<<---configureFlutterEngine--->>>".withAndroidPrefix())

        Sentry.init("https://06a570b6f7d5489eade00b7f60d797c0@o460339.ingest.sentry.io/5478173",
                AndroidSentryClientFactory(this.applicationContext))
        try {
            Log.d("sentrytest1","try")
            throw Exception("This is a test.")

        } catch (e: Exception) {
            Log.d("sentrytest1","catch")
            Sentry.capture(e)
        }

        GeneratedPluginRegistrant.registerWith(flutterEngine)

//        var filePath = "/data/service-account.json";
//        filePath = Environment.getDataDirectory().path+"/service-account.json";
//        var stream = assets.open("service-account.json");
//        filePath = resources.openRawResource(R.raw.)


//        FirebaseInstanceId.getInstance().instanceId
//                .addOnCompleteListener(OnCompleteListener { task ->
//                    if (!task.isSuccessful) {
//                        Log.d(TAG, "getInstanceId failed", task.exception)
//                        return@OnCompleteListener
//                    }
//
//                    // Get new Instance ID token
//                    val token = task.result?.token
//
//                    // Log and toast
////                    Log.d(TAG, token)
//                    Log.e(TAG, token.toString().withAndroidPrefix())
//                    System.out.println(token);
//                    Toast.makeText(instance, token, Toast.LENGTH_SHORT).show()
//                })

        NknWalletPlugin(flutterEngine)
        clientPlugin = NknClientPlugin(this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor, N_MOBILE_COMMON).setMethodCallHandler { methodCall, result ->
            if (methodCall.method == "backDesktop") {
                result.success(true)
                moveTaskToBack(false)
            }
            else if (methodCall.method == "isActive") {
                result.success(isActive)
            }
            else {
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
//        val content = File("serviceaccount.json").readText()
//        println(content)
//        val fileStream : InputStream = assets.open("src/assets/serviceaccount.json")
//        val input = Context.asse
//
//        val service = GooglePushService()
//        val token = service.getAuth(fileStream);
//        Log.e(TAG,"Token is "+token.toString());
        Log.e(TAG, "<<<---onCreate--->>>".withAndroidPrefix())
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "<<<---onStart--->>>".withAndroidPrefix())
        isActive = true
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
        isActive = false
        super.onStop()
    }

    override fun onDestroy() {
        clientPlugin?.close()
        Log.e(TAG, ">>>---onDestroy---<<<".withAndroidPrefix())
        super.onDestroy()
    }
}
