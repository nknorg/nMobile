/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.dchat

import android.content.Context
import android.content.res.AssetManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.dart.DartExecutor.DartCallback
import io.flutter.embedding.engine.plugins.shim.ShimPluginRegistry
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.JSONMethodCodec
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.FlutterCallbackInformation
import io.flutter.view.FlutterMain
import org.nkn.mobile.app.App
import org.nkn.mobile.app.GlobalConf
import org.nkn.mobile.app.NknClientPlugin
import org.nkn.mobile.app.abs.Tag
import org.nkn.mobile.app.NknWalletPlugin

/**
 * @author Wei.Chou
 * @version 1.0, 27/06/2020
 */
class MessagingServiceFlutterPlugin(private val context: Context, private val onInitialized: () -> Unit) :
        MethodChannel.MethodCallHandler/*, EventChannel.StreamHandler*/, Tag {
    val TAG by lazy { tag() }

    companion object {
        const val PLUGIN_PATH = "org.nkn.mobile.app/android_messaging_service"
        const val CONFIG_CHANNEL_NAME = "$PLUGIN_PATH/config"
        const val INIT_CHANNEL_NAME = "$PLUGIN_PATH/initialize"
        const val CONFIG_METHOD_NAME = "registerMessagingCallback"
        const val REGISTERED_CALLBACK_ID = "callback_id"
        const val EVENT_AND_DATA = "event_and_data"
        const val INITIALIZED = "initialized"

        fun config(engine: FlutterEngine): Config {
            return Config(engine)
        }

        class Config(engine: FlutterEngine) : MethodChannel.MethodCallHandler, Tag {
            val TAG by lazy { tag() }

            init {
                MethodChannel(engine.dartExecutor, CONFIG_CHANNEL_NAME).setMethodCallHandler(this)
            }

            override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                when (call.method) {
                    CONFIG_METHOD_NAME -> {
                        val args = call.arguments as List<Any>
                        Log.i(TAG, "${call.method}: $args")
                        val dispatcherId = args[0].toString()
                        val realCallbackId = args[1].toString()
                        GlobalConf.STATE.storeRegisteredMsgCallbackIds(listOf(dispatcherId, realCallbackId))
                    }
                    else -> {
                        Log.e(TAG, call.method)
                    }
                }
            }
        }
    }

    init {
        obtainConfig()
        startBackgroundIsolate()
    }

    private lateinit var dispatcherMethodId: String
    private lateinit var realCallbackId: String
    private lateinit var flutterEngine: FlutterEngine
    private lateinit var initChannel: MethodChannel
    private lateinit var clientPlugin: NknClientPlugin

    private fun obtainConfig() {
        val list = GlobalConf.STATE.getRegisteredMsgCallbackIds()
        Log.i(TAG, "obtainConfig: $list")
        dispatcherMethodId = list[0]
        realCallbackId = list[1]
    }

    private fun startBackgroundIsolate() {
        flutterEngine = FlutterEngine(context)
        val executor: DartExecutor = flutterEngine.getDartExecutor()
        initMethodChannel()
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(dispatcherMethodId.toLong())
        if (callbackInfo == null) {
            Log.e(TAG, "Fatal: failed to find callback: $dispatcherMethodId")
            return
        }
        Log.i(TAG, "startBackgroundIsolate: $flutterEngine")
        val appBundlePath: String = FlutterMain.findAppBundlePath()
        val assets: AssetManager = context.assets
        val dartCallback: DartExecutor.DartCallback = DartCallback(assets, appBundlePath, callbackInfo)
        executor.executeDartCallback(dartCallback)
    }

    private fun initMethodChannel() {
        initChannel = MethodChannel(flutterEngine.dartExecutor, INIT_CHANNEL_NAME)
        initChannel.setMethodCallHandler(this)

        clientPlugin = NknClientPlugin(null, flutterEngine)
        NknWalletPlugin(flutterEngine)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall | ${call.method}")
        when (call.method) {
            INITIALIZED -> {
                App.handler().post {
                    onInitialized()
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun onNativeReady() {
        App.runOnMainThread {
            initChannel.invokeMethod(
                    "",
                    hashMapOf(
                            REGISTERED_CALLBACK_ID to realCallbackId,
                            EVENT_AND_DATA to hashMapOf(
                                    "event" to "onNativeReady",
                                    "data" to ""
                            )
                    )
            )
        }
    }

    fun destroy() {
        clientPlugin.close()
        App.runOnMainThread {
            try {
                initChannel.invokeMethod(
                        "",
                        hashMapOf(
                                REGISTERED_CALLBACK_ID to realCallbackId,
                                EVENT_AND_DATA to hashMapOf(
                                        "event" to "destroy",
                                        "data" to ""
                                )
                        )
                )
            } finally {
                flutterEngine.destroy()
            }
        }
    }
}
