/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app

//import com.google.firebase.FirebaseApp

import android.app.Activity
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.*
import android.os.StrictMode.VmPolicy
import android.util.Log
import io.flutter.app.FlutterApplication
import nkn.Wallet
import org.nkn.mobile.app.abs.Tag
import org.nkn.mobile.app.dchat.DChatServiceForFlutter
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix
import java.util.concurrent.TimeUnit

/**
 * @author Wei.Chou
 * @version 1.0, 05/02/2020
 */
class App : FlutterApplication(), Tag {
    val TAG by lazy { tag() }

    init {
        instance = this
    }

    override fun onCreate() {
//        FirebaseApp.initializeApp(this)
        super.onCreate()
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, bundle: Bundle?) {}

            override fun onActivityStarted(activity: Activity) {
                onStartStopInsCount++
                DChatServiceForFlutter.stopFg(applicationContext)
            }

            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityStopped(activity: Activity) {
                if (--onStartStopInsCount == 0) {
                    mainActy = activity as MainActivity
                    DChatServiceForFlutter.startFg(applicationContext)
                }
            }

            override fun onActivityDestroyed(activity: Activity) {
                if (activity == mainActy) mainActy = null
                if (onStartStopInsCount <= 0) {
                    DChatServiceForFlutter.forceStartWork(applicationContext)
                }
            }
        })
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // android.os.FileUriExposedException: file:///storage/emulated/0/DCIM/Camera/IMG_xxx.jpg
            // exposed beyond app through Intent.getData()
            StrictMode.setVmPolicy(VmPolicy.Builder().build())
        }

        val filter = IntentFilter()
        filter.addAction(Intent.ACTION_SCREEN_OFF)
        filter.addAction(Intent.ACTION_SCREEN_ON)
        filter.addAction(Intent.ACTION_USER_PRESENT)
        registerReceiver(object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON -> {
                        isScreenOn = true
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        isScreenOn = false
                        handler.removeCallbacks(serviceForceStartWorkRun)
                        handler.postDelayed(serviceForceStartWorkRun, TimeUnit.MINUTES.toMillis(1))
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        isScreenOn = true
                    }
                    else -> {
                    }
                }
            }
        }, filter)
    }

    private fun isMainProcess(): Boolean {
        fun getProcessName(pid: Int): String? {
            val actyManager = getSystemService(ActivityManager::class.java)
            for (info in actyManager.getRunningAppProcesses()) {
                Log.i(TAG, String.format("[process]id: %s, name: %s.", info.pid, info.processName).withAndroidPrefix())
                if (info.pid == pid) return info.processName
            }
            return null
        }

        val packageName = getProcessName(Process.myPid())!!
        return packageName.indexOf(':') < 0
    }

    private val serviceForceStartWorkRun by lazy {
        Runnable {
            if (!isScreenOn && onStartStopInsCount <= 0 && isMainProcess()) {
                DChatServiceForFlutter.forceStartWork(applicationContext)
                postDelayed(TimeUnit.SECONDS.toMillis(10)) {
                    if (!isScreenOn && onStartStopInsCount <= 0) {
                        Log.w(TAG, "pauseClient on ui process: ${mainActy?.javaClass?.name}".withAndroidPrefix())
                        mainActy?.clientPlugin?.pauseClient()
                    }
                }
            }
        }
    }

    fun onUiClientCreated() {
        postDelayed(TimeUnit.SECONDS.toMillis(10)) {
            // `onUiClientCreated()` is always at `main process`.
            if (isScreenOn && onStartStopInsCount > 0/* && isMainProcess()*/) {
                Log.w(TAG, "service force stop work".withAndroidPrefix())
                DChatServiceForFlutter.forceStopWork(applicationContext)
            }
        }
    }

    val handler by lazy { Handler(mainLooper) }

    fun postOnIdle(times: Int = -1, action: () -> Unit) {
        handler.looper.queue.addIdleHandler(MyIdleHandler(times, action))
    }

    private var onStartStopInsCount = 0
    private var isScreenOn: Boolean = true
    private var mainActy: MainActivity? = null

    companion object {
        @Volatile
        private lateinit var instance: App

        fun get() = instance

        fun runOnMainThread(action: () -> Unit) {
            if (Looper.getMainLooper().isCurrentThread) {
                action()
            } else handler().post(action)
        }

        fun handler() = get().handler

        fun postOnIdle(times: Int = -1, action: () -> Unit) {
            get().postOnIdle(times, action)
        }

        fun postDelayed(timeDelayed: Long, action: () -> Unit) {
            handler().postDelayed({
                action()
            }, timeDelayed)
        }

        fun withPackageNamePrefix(name: String) = "${get().packageName}.$name"

        class MyIdleHandler(val times: Int, val action: () -> Unit) : MessageQueue.IdleHandler {
            private var n = 0
            override fun queueIdle(): Boolean {
                action()
                return ++n < times
            }
        }
    }
}
