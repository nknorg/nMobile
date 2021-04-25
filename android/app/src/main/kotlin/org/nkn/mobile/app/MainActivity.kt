package org.nkn.mobile.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.nkn.mobile.app.channels.impl.Common


class MainActivity : FlutterActivity() {
    private lateinit var common: Common

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        common = Common(this.activity)
        common.install(flutterEngine.dartExecutor.binaryMessenger)
    }
}
