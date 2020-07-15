/*
 * Copyright (C) 2020-present, Chenai Nakam(chenai.nakam@gmail.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package hobby.wei.c.core

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * 忽略电池优化，以使得`APP`可以在后台长期联网。
 *
 * @author Chenai Nakam(chenai.nakam@gmail.com)
 * @version 1.0, 22/02/2020
 */
interface IgnoreBatteryOptReq {
    val TAG: String
    val context: Context

    fun acquireWakeLock(ignoreBatteryOpt: Boolean) {
        try {
            val powerManager = context.getSystemService(PowerManager::class.java)
            mWakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.javaClass.name)
            mWakeLock?.acquire(Long.MAX_VALUE)
            if (ignoreBatteryOpt) {
                ensureIgnoringBatteryOptimizations(powerManager) {
                    context.startActivity(intent4ReqIgnoringBatteryOpt().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "", e)
        }
    }

    fun releaseWakeLock() {
        mWakeLock?.release()
    }

    /**
     * 需要触发`android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` Intent
     * 来触发一个系统对话框。
     * 需要权限`android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`。
     * （注意：只有在`AndroidManifest.xml`中申请了该权限，才能显示对话框。）
     *
     * https://developer.android.com/training/monitoring-device-state/doze-standby#support_for_other_use_cases
     */
    fun ensureIgnoringBatteryOptimizations(powerMgr: PowerManager? = null, action: () -> Unit) {
        val powerManager = powerMgr ?: context.getSystemService(PowerManager::class.java)
        if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
            action()
        }
    }

    /**
     * 需要写个介绍页，然后再启动这个`Intent`以引导用户自行设置。
     * <p>
     * 理论上启动一个[[ensureIgnoringBatteryOptimizations()]]就可以，但
     * 现实上我们发现定制的系统仍然不保险，所以最好再启动这个，引导用户自行设置。
     * <p>
     * 注：这个`startActivityForResult()`没什么用。
     */
    fun intentToSettings() = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

    fun intent4ReqIgnoringBatteryOpt() = Intent(
        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
    ).setData(Uri.parse("package:${context.packageName}"))
    // 因为可能使用`startActivityForResult()`，所以不要下面这一句。从`Service`里面启动也不会有问题（Android 10 有问题）。
    // .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    var mWakeLock: PowerManager.WakeLock?
}
