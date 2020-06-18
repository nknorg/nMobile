package org.nkn.nmobile.application

import android.app.Activity
import android.app.Application
import android.os.*
import android.os.StrictMode.VmPolicy
import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import nkn.Account
import com.transistorsoft.flutter.backgroundfetch.BackgroundFetchPlugin;
import io.flutter.plugins.GeneratedPluginRegistrant

class App : FlutterApplication()  {

    init {
        instance = this
    }

    override fun onCreate() {
        super.onCreate()

        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            var onStartStopInsCount = 0
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            }

            override fun onActivityStarted(activity: Activity) {
                onStartStopInsCount++
            }

            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityStopped(activity: Activity) {
                if (--onStartStopInsCount == 0) {
                    //                    DChatMessagingService.startFg(applicationContext)
                }

            }

            override fun onActivityDestroyed(activity: Activity) {}
        })
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // android.os.FileUriExposedException: file:///storage/emulated/0/DCIM/Camera/IMG_xxx.jpg
            // exposed beyond app through Intent.getData()
            StrictMode.setVmPolicy(VmPolicy.Builder().build())
        }
    }

    val handler by lazy { Handler(mainLooper) }

    fun postOnIdle(times: Int = -1, action: () -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            handler.looper.queue.addIdleHandler(MyIdleHandler(times, action))
        }
    }


    companion object {
        @Volatile
        private lateinit var instance: App

        @Volatile
        private var account: Account? = null

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

        fun getNknAccount(): Account? = account

        fun clearNknAccount() {
            account = null
        }

        class MyIdleHandler(val times: Int, val action: () -> Unit) : MessageQueue.IdleHandler {
            private var n = 0
            override fun queueIdle(): Boolean {
                action()
                return ++n < times
            }
        }
    }
}
