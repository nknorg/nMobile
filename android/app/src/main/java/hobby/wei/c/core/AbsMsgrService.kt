/*
 * Copyright (C) 2017-present, Chenai Nakam(chenai.nakam@gmail.com)
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

import android.content.Intent
import android.database.Observable
import android.os.*
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.app.ServiceCompat.StopForegroundFlags
import hobby.wei.c.tool.Retry
import hobby.wei.c.tool.RetryByHandler
import org.nkn.mobile.app.App
import org.nkn.mobile.app.abs.StartMe
import java.lang.ref.WeakReference

/**
 * @author Chenai Nakam(chenai.nakam@gmail.com)
 * @version 1.0, 22/05/2018
 */
abstract class AbsMsgrService : AbsSrvce(), RetryByHandler, StartMe.Const {
    @Volatile
    private var mAllClientDisconnected = true

    @Volatile
    private var mStopRequested = false
    private var mCallStartCount = 0
    private var mCallStopCount = 0

    /**
     * 子类重写本方法以处理`Client`端发过来的消息。
     *
     * @param msg `Client`端发过来的消息对象。
     */
    protected open fun handleClientMsg(msg: Message, handler: Handler): Unit = when (msg.what) {
        1234567 -> {
            Log.i(
                TAG, String.format(
                    "handleClientMsg | msg > what: %s, content: %s.", msg.what,
                    (msg.obj as Bundle).getString("msg_key")
                )
            )
            val answer = Message.obtain()
            answer.what = 7654321
            val b = Bundle()
            b.putString("msg_key", "<<< 这是一个测试`应答`消息 <<<。")
            answer.obj = b
            sendMsg2Client(answer)
        }
        else -> {
        }
    }

    /**
     * 请求启动任务。
     * 由于服务需要时刻保持任务正常运行。Client可能会由于某些原因发出多次启动命令。如果本服务
     * 对任务管理较严谨，可忽略后面的（当`callCount > 0`时）命令；否则应该每次检查是否需要重新启动。
     *
     * @param callCount 当前回调被呼叫的次数，从`0`开始（`0`为第一次）。
     */
    abstract fun onStartWork(callCount: Int)

    /**
     * 请求停止任务。
     *
     * @return `-1`表示不可以关闭（应该继续运行）；`0`表示可以关闭；`> 0`表示延迟该时间后再来询问。
     * @param callCount 当前回调被呼叫的次数，从`0`开始（`0`为第一次）。
     */
    abstract fun onStopWork(callCount: Int): Int

    /** 请求调用`startForeground()`。 */
    abstract fun onStartForeground()

    /** 请求调用`stopForeground()`（注意：不是终止服务，而是仅仅把前台服务切换到后台。终止服务只能`stopSelf()`）。 */
    open fun onStopForeground(): Unit = stopForeground(true)

    fun stopForegroundCompat(@StopForegroundFlags flags: Int): Unit = ServiceCompat.stopForeground(
        this, flags
    )

    /**
     * 子类重写该方法以消化特定命令。
     *
     * @return `true`表示消化了参数`intent`携带的命令（这意味着本父类不再继续处理命令），
     *         `false`表示没有消化（即：没有自己关注命令）。
     */
    open fun confirmIfCommandConsumed(intent: Intent?): Boolean = false

    fun sendMsg2Client(msg: Message) {
        fun shouldFinish() = isDestroyed() || (mStopRequested && mAllClientDisconnected)
        if (!shouldFinish()) clientHandler.post {
            retryForceful(1200) {
                when {
                    hasClient() -> {
                        mMsgObservable.sendMessage(msg)
                        true
                    }
                    shouldFinish() -> true /*中断*/
                    else -> false
                }
            }
        }
    }

    override val delayer: Retry.Delayer by lazy { this.delayerOf() }
    override fun delayerHandler(): Handler = clientHandler

    /** 在没有client bind的情况下，会停止Service，否则等待最后一个client取消bind的时候会自动断开。 **/
    fun requestStopService() {
        mStopRequested = true
        confirmIfSignify2Stop()
    }

    fun hasClient() = !mAllClientDisconnected

    fun isStopRequested() = mStopRequested

    private val mMsgObservable by lazy { MsgObservable() }

    private val mHandlerThread by lazy {
        val ht = HandlerThread(javaClass.name + ".mHandlerThread", Process.THREAD_PRIORITY_BACKGROUND)
        ht.start()
        ht
    }

    /** 主要用于客户端消息的`接收`和`回复`。 */
    protected val clientHandler: Handler by lazy {
        object : Handler(mHandlerThread.looper) {
            override fun handleMessage(msg: Message) {
                if (msg.what == MSG_REPLY_TO) {
                    if (msg.replyTo != null) {
                        mAllClientDisconnected = false
                        mMsgObservable.registerObserver(MsgObserver(msg.replyTo, mMsgObservable))
                    }
                } else if (msg.what == MSG_UN_REPLY) {
                    msg.replyTo?.let {
                        mMsgObservable.unregister(it)
                    }
                } else if (isStopRequested() || isDestroyed()) {
                    Log.w(
                        TAG,
                        String.format(
                            "clientHandler.handleMessage | BLOCKED. >>> stopRequested: %s, destroyed: %s.",
                            isStopRequested(),
                            isDestroyed()
                        )
                    )
                } else handleClientMsg(msg, clientHandler)
            }
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        Log.w(TAG, String.format("onBind | intent: %s.", intent))
        // 注意：`onUnbind()`之后，如果再次`bindService()`并不一定会再走这里。即：`onBind()`和`onUnbind()`并不对称。
        // 但只要`onUnbind()`返回`true`，下次会走`onRebind()`。
        mAllClientDisconnected = false
        return Messenger(clientHandler).binder
    }

    override fun onRebind(intent: Intent) {
        mAllClientDisconnected = false
        super.onRebind(intent)
    }

    override fun onUnbind(intent: Intent): Boolean { // 当所有的bind连接都断开之后会回调
        mAllClientDisconnected = true
        mMsgObservable.unregisterAll()
        confirmIfSignify2Stop()
        super.onUnbind(intent)
        // 默认返回`false`（注意：下次`bind`的时候既不执行`onBind()`，也不执行`onRebind()`）。当返回`true`时，下次的`bind`操作将执行`onRebind()`。
        return true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!confirmIfSignify2Stop(intent) // 注意这几个顺序所表达的优先级
            && !confirmIfSignify2ToggleForeground(intent)
            && !confirmIfCommandConsumed(intent)
        ) {
            App.handler().post {
                // 本服务就是要时刻保持连接畅通的
                onStartWork(mCallStartCount)
                mCallStartCount += 1
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }

    private fun confirmIfSignify2ToggleForeground(intent: Intent?): Boolean = if (intent != null) {
        when {
            intent.getBooleanExtra(CMD_EXTRA_START_FOREGROUND, false) -> {
                onStartForeground()
                true
            }
            intent.getBooleanExtra(CMD_EXTRA_STOP_FOREGROUND, false) -> {
                onStopForeground()
                true
            }
            else -> false
        }
    } else false

    private fun confirmIfSignify2Stop(): Boolean = confirmIfSignify2Stop(null)

    private fun confirmIfSignify2Stop(intent: Intent?): Boolean {
        if (intent != null) mStopRequested = intent.getBooleanExtra(CMD_EXTRA_STOP_SERVICE, false)
        // 让请求跟client的msg等排队执行
        if (!isDestroyed() && mStopRequested) clientHandler.post { postStopSelf(0) }
        return mStopRequested
    }

    private fun postStopSelf(delay: Int): Unit = App.postDelayed(delay.toLong()) {
        if (!isDestroyed() && mStopRequested && mAllClientDisconnected) {
            when (val time = onStopWork(mCallStopCount)) {
                -1 -> {// 可能又重新bind()了
                    require(!mStopRequested || !mAllClientDisconnected) {
                        "It should be closed according to the current status. You can call`onCallStopWork()`return`>0`to delay the time before asking again."
                    }
                }
                0 -> stopSelf() //完全准备好了，该保存的都保存了，那就关闭吧。
                else -> postStopSelf(time)
            }
        }
        mCallStopCount += 1
    }

    override fun onDestroy() {
        super.onDestroy()
        clientHandler.post {
            mHandlerThread.quitSafely()
        }
    }

    companion object {
        class MsgObservable : Observable<MsgObserver>() {
            fun sendMessage(msg: Message) {
                synchronized(mObservers) {
                    var i = mObservers.size - 1
                    while (i >= 0) {
                        //Message不可重复发送，见`msg.markInUse()`
                        mObservers[i].onMessage(Message.obtain(msg))
                        i -= 1
                    }
                }
            }

            fun unregister(msgr: Messenger) {
                val msgObs = mObservers.firstOrNull { it.msgr == msgr }
                msgObs?.let {
                    synchronized(mObservers) {
                        val i = mObservers.indexOf(it)
                        if (i >= 0) unregisterObserver(it)
                    }
                }
            }
        }

        class MsgObserver(val msgr: Messenger, obs: MsgObservable) {
            private val obsRef: WeakReference<MsgObservable> = WeakReference<MsgObservable>(obs)

            fun onMessage(msg: Message) {
                try {
                    msgr.send(msg)
                } catch (ex: RemoteException) {
                    if (!msgr.binder.pingBinder()) {
                        obsRef.get()?.unregisterObserver(this)
                    }
                }
            }
        }
    }
}
