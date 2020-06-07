package org.nkn.nmobile

import android.os.AsyncTask
import android.os.HandlerThread
import android.os.Process
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import nkn.Nkn
import nkn.TransactionConfig
import nkn.WalletConfig
import org.nkn.mobile.app.util.Bytes2String.decodeHex
import org.nkn.mobile.app.util.Bytes2String.toHex
import org.nkn.nmobile.NknWalletEventPlugin.Companion.walletEventSink
import org.nkn.nmobile.app.util.WalletUtils
import org.nkn.mobile.app.util.ApkInstaller
import org.nkn.nmobile.application.App

class InstallApkMethodPlugin : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installApk" -> {
                installApk(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("apk_file_path")!!
        Log.d("InstallApkMethodPlugin", "installApk | path: $path")
        ApkInstaller.installApk(App.get(), path)
        result.success(path)
    }
}
