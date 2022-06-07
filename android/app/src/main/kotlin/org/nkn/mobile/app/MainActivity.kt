package org.nkn.mobile.app

import android.os.Bundle
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import org.nkn.mobile.app.channels.impl.Common
import org.nkn.mobile.app.push.APNSPush

class MainActivity : FlutterFragmentActivity() {

    companion object {
        lateinit var instance: MainActivity
    }

    // var blurWindow: BlurWindow? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        instance = this
        // blurWindow = BlurWindow(this)
    }

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {
        super.onCreate(savedInstanceState, persistentState)
        instance = this
    }

    override fun onStart() {
        super.onStart()
    }

    override fun onResume() {
        // blurWindow?.stopBLur()
        super.onResume()
    }

    override fun onPause() {
        // blurWindow?.startBlur()
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
    }

    override fun onSaveInstanceState(outState: Bundle, outPersistentState: PersistableBundle) {
        super.onSaveInstanceState(outState, outPersistentState)
    }

    override fun onStop() {
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        instance = this
        super.configureFlutterEngine(flutterEngine)

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        Common.register(flutterEngine)

        APNSPush.openClient(assets)
    }

    override fun onDestroy() {
        super.onDestroy()

        APNSPush.closeClient()
    }
}
