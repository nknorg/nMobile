/*
 * Copyright (C) 2018-present, Chenai Nakam(chenai.nakam@gmail.com)
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

package hobby.wei.c.tool

import android.util.Log

/**
 * @author Chenai Nakam(chenai.nakam@gmail.com)
 * @version 1.0, 12/06/2018
 */
interface Retry {
    /**
     * 重试一个操作指定的次数，直到成功，或者用完次数。
     *
     * @param delayMillis 延迟多长时间后重试。单位：毫秒。
     * @param times       最多重试多少次。
     * @param increase    延时递增，在`delay`的基础上。
     * @param from        从什么时间开始递增。
     * @param action      具体要执行的操作。该函数的参数为`times`（最后一次是`1`），返回`true`表示成功，结束重试。
     * @param custom      用于延迟`action`执行时间的延迟器。
     */
    fun retryForceful(
        delayMillis: Int,
        times: Int = 8,
        increase: Int = 0,
        from: Int = times,
        custom: Delayer? = null,
        action: (Int) -> Boolean
    ) {
        if (times > 0) {
            Log.i(
                "retryForceful",
                String.format(
                    "delayMillis: %s, times: %s, increase: %s, from: %s, action: %s.",
                    delayMillis, times, increase, from, action
                )
            )
            if (!action(times) && times > 1) {
                val t = if ((times - 1) < from) delayMillis + increase * (from - (times - 1)) else delayMillis
                if (custom != null) {
                    custom.delay(t) {
                        retryForceful(delayMillis, times - 1, increase, from, custom, action)
                    }
                } else {
                    delayer.delay(t) {
                        retryForceful(delayMillis, times - 1, increase, from, custom, action)
                    }
                }
            }
        }
    }

    fun delay(delayMillis: Int, action: () -> Unit) {
        delayer.delay(delayMillis, action)
    }

    val delayer: Delayer

    interface Delayer {
        fun delay(delayMillis: Int, action: () -> Unit)
    }
}

interface RetryBySleep : Retry {
    override val delayer: Retry.Delayer

    /**在实现类上写[override val delayer: Retry.Delayer = delayerOf()]*/
    fun delayerOf() = object : Retry.Delayer {
        override fun delay(delayMillis: Int, action: () -> Unit) {
            Thread.sleep(delayMillis.toLong())
            action()
        }
    }
}
