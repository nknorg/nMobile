/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app

import android.os.*
import android.app.*
import android.os.StrictMode.VmPolicy
//import com.google.firebase.FirebaseApp
import nkn.Wallet
import org.nkn.mobile.app.abs.Tag
import org.nkn.mobile.app.dchat.DChatServiceForFlutter
import org.nkn.mobile.app.util.Bytes2String.withAndroidPrefix

import io.flutter.app.FlutterApplication
import java.util.concurrent.TimeUnit
import android.util.Log

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
            var onStartStopInsCount = 0
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
                    DChatServiceForFlutter.startFg(applicationContext)
//                    postDelayed(2000/*TimeUnit.MINUTES.toMillis(10)*/) {
//                        if (onStartStopInsCount <= 0 /*&& isMainProcess()*/) {
//                            Log.e(TAG, "finish activity: ${activity.javaClass.name}".withAndroidPrefix())
//                            activity.finish()
//                            // Can't trigger appTasks not running.
//                            //Process.killProcess(Process.myPid())
//                        }
//                    }
                }
            }

            override fun onActivityDestroyed(activity: Activity) {
                if (onStartStopInsCount <= 0) {
                    // trigger service `onStartWork()`
                    DChatServiceForFlutter.start(applicationContext)
                }
            }
        })
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // android.os.FileUriExposedException: file:///storage/emulated/0/DCIM/Camera/IMG_xxx.jpg
            // exposed beyond app through Intent.getData()
            StrictMode.setVmPolicy(VmPolicy.Builder().build())
        }
    }

    fun isMainProcess(): Boolean {
        fun getProcessName(pid: Int): String? {
            val actyManager = getSystemService(ActivityManager::class.java)
            for (info in actyManager.getRunningAppProcesses()) {
                Log.i(TAG, String.format("[process]id: %s, name: %s.", info.pid, info.processName).withAndroidPrefix())
                if (info.pid == pid) return info.processName
            }
            return null
        }

        val packageName = getProcessName(Process.myPid())
        return packageName!!.indexOf(':') < 0
    }

    val handler by lazy { Handler(mainLooper) }

    fun postOnIdle(times: Int = -1, action: () -> Unit) {
        handler.looper.queue.addIdleHandler(MyIdleHandler(times, action))
    }

    companion object {
        @Volatile
        private lateinit var instance: App

        @Volatile
                /*private*/ var wallet: Wallet? = null

        fun get() = instance

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
