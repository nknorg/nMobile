package org.nkn.mobile.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import org.nkn.mobile.app.channels.impl.Common


class MainActivity : FlutterFragmentActivity() {
    private lateinit var common: Common

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        common = Common(this)
        common.install(flutterEngine.dartExecutor.binaryMessenger)
    }
}
