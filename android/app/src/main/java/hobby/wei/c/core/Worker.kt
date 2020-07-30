/*
 * Copyright (C) 2017-present, Wei Chou(weichou2010@gmail.com)
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

import java.util.concurrent.*
import java.util.concurrent.atomic.AtomicInteger

/**
 * 优化的线程池实现。
 *
 * @author Wei Chou(weichou2010@gmail.com)
 * @version 1.0, 11/02/2017
 */
object Worker {
    private val sThreadFactory by lazy {
        object : ThreadFactory {
            val mIndex = AtomicInteger(0)

            override fun newThread(runnable: Runnable): Thread {
                val thread = Thread(runnable, "pool-thread-" + Worker.javaClass.name + "#" + mIndex.getAndIncrement())
                resetThread(thread)
                return thread
            }
        }
    }

    private fun resetThread(thread: Thread) {
        Thread.interrupted()
        if (thread.isDaemon) thread.isDaemon = false
    }

    private val sPoolWorkQueue: BlockingQueue<Runnable> by lazy {
        object : LinkedTransferQueue<Runnable>() {
            override fun offer(r: Runnable): Boolean {
                /* 如果不放入队列并返回false，会迫使增加线程。但是这样又会导致总是增加线程，而空闲线程得不到重用。
            因此在有空闲线程的情况下就直接放入队列。若大量长任务致使线程数增加到上限，
            则threadPool启动reject流程(见ThreadPoolExecutor构造器的最后一个参数)，此时再插入到本队列。
            这样即完美实现[先增加线程数到最大，再入队列，空闲释放线程]这个基本逻辑。*/
                return sThreadPoolExecutor.activeCount < sThreadPoolExecutor.poolSize && super.offer(r)
            }
        }
    }

    private val sThreadPoolExecutor: ThreadPoolExecutor by lazy {
        val cpuCount = Runtime.getRuntime().availableProcessors()
        val corePoolSize = cpuCount + 1
        val maxPoolSize = cpuCount * 5 + 1
        /* 空闲线程保留时间。单位: 秒。*/
        val keepAliveTime = 10L
        ThreadPoolExecutor(corePoolSize, maxPoolSize,
            keepAliveTime, TimeUnit.SECONDS, sPoolWorkQueue, sThreadFactory,
            RejectedExecutionHandler { r, executor ->
                try {
                    sPoolWorkQueue.offer(r, 1, TimeUnit.DAYS)
                } catch (ignore: InterruptedException/*不可能出现*/) {
                    throw ignore
                }
            })
    }

    fun execute(runnable: Runnable) {
        sThreadPoolExecutor.execute(runnable)
    }

    fun execute(action: () -> Unit) {
        sThreadPoolExecutor.execute(action)
    }
}
