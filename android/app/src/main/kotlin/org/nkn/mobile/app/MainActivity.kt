package org.nkn.mobile.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import org.nkn.mobile.app.channels.impl.Common
import org.nkn.mobile.app.push.APNSPush

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        Common.register(this, flutterEngine)

        APNSPush.openClient(assets)
    }

    override fun onDestroy() {
        super.onDestroy()

        APNSPush.closeClient()
    }
}
