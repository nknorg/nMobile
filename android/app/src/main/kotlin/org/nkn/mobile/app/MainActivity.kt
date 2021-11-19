package org.nkn.mobile.app

import android.os.Bundle
import android.os.PersistableBundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import org.nkn.mobile.app.channels.impl.Common
import org.nkn.mobile.app.push.APNSPush

class MainActivity : FlutterFragmentActivity() {

    companion object {
        lateinit var instance: MainActivity
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {
        super.onCreate(savedInstanceState, persistentState)
        instance = this
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
