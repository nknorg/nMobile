package org.nkn.mobile.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.StrictMode
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import io.sentry.android.AndroidSentryClientFactory
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix
import java.util.*


class MainActivity : FlutterFragmentActivity(){

    val instance by lazy { this } //这里使用了委托，表示只有使用到instance才会执行该段代码

    companion object {
        private const val N_MOBILE_COMMON = "org.nkn.nmobile/native/common"
    }

    /*private */var clientPlugin: NknClientPlugin? = null
    private var isActive : Boolean =  false;

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.e("MainActivityE", "<<<---configureFlutterEngine--->>>".withAndroidPrefix())

        Sentry.init("https://e8e2c15b0e914295a8b318919f766701@o466976.ingest.sentry.io/5483308",
                AndroidSentryClientFactory(this.applicationContext))

//        val am: AssetManager = assets;
//        var `is`:InputStream = am.open("nmobile-firebase-adminsdk-scioc-a2002be548.json");
//        val inputAsString = `is`.bufferedReader().use { it.readText() }  // defaults to UTF-8
//        Log.e("Inopasndlkasj", inputAsString);
        

        //send V1 Message
//        `is` = am.open("nmobile-firebase-adminsdk-scioc-a2002be548.json");
//        val token = service.getAuth(`is`);
//        Log.e(TAG, "Token is " + token.toString());
//        service.setAccessToken(token.toString());
//        service.sendMessage()

        // send V0 Message
//        service.sendV0Message();

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
        clientPlugin = NknClientPlugin(this, flutterEngine)
        NknWalletPlugin(flutterEngine)
//        MessagingServiceFlutterPlugin.config(flutterEngine)
    }

    fun onClientCreated() {
        App.get().onUiClientCreated()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT > 9) {
            val policy = StrictMode.ThreadPolicy.Builder().permitAll().build()
            StrictMode.setThreadPolicy(policy)
        }
        Log.e("MainActivityE", "<<<---onCreate--->>>".withAndroidPrefix())
    }

    override fun onStart() {
        super.onStart()
        Log.d("MainActivityE", "<<<---onStart--->>>".withAndroidPrefix())
        isActive = true
    }

    override fun onResume() {
        super.onResume()
        Log.d("MainActivityE", "<<<---onResume--->>>".withAndroidPrefix())
    }

    override fun onPause() {
        Log.d("MainActivityE", ">>>---onPause---<<<".withAndroidPrefix())
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.d("MainActivityE", ">>>---onSaveInstanceState---<<<".withAndroidPrefix())
        // e.g:
        val bundle = Bundle()
        bundle.putString("key", "value")
        outState.putParcelable("app:$\"MainActivityE\"", bundle)
        outState.putString("app:${"MainActivityE".toLowerCase(Locale.US)}:key", "value")
    }

    override fun onStop() {
        Log.d("MainActivityE", ">>>---onStop---<<<".withAndroidPrefix())
        isActive = false
        super.onStop()
    }

    override fun onDestroy() {
        clientPlugin?.close()
        Log.e("MainActivityE", ">>>---onDestroy---<<<".withAndroidPrefix())
        super.onDestroy()
    }

    public fun openNotificationFunction(){
        val manager = NotificationManagerCompat.from(this)
        val isOpened = manager.areNotificationsEnabled()

        if (isOpened) {

        } else {
            val intent: Intent = Intent()
            try {
                intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS

                //8.0及以后版本使用这两个extra.  >=API 26
                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                intent.putExtra(Settings.EXTRA_CHANNEL_ID, applicationInfo.uid)

                //5.0-7.1 使用这两个extra.  <= API 25, >=API 21
                intent.putExtra("app_package", packageName)
                intent.putExtra("app_uid", applicationInfo.uid)

                startActivity(intent)
            } catch (e: Exception) {
                e.printStackTrace()

                //其他低版本或者异常情况，走该节点。进入APP设置界面
                intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                intent.putExtra("package", packageName)

                //val uri = Uri.fromParts("package", packageName, null)
                //intent.data = uri
                startActivity(intent)
            }
        }
    }



}
