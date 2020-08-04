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

package hobby.wei.c.core

import android.content.ComponentName
import android.content.ServiceConnection
import android.os.*
import android.util.Log
import hobby.wei.c.tool.Retry
import hobby.wei.c.tool.RetryByHandler
import org.nkn.mobile.app.abs.StartMe
import org.nkn.mobile.app.abs.Tag
import org.nkn.mobile.app.BuildConfig
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * @author Chenai Nakam(chenai.nakam@gmail.com)
 * @version 1.0, 26/05/2018
 */
abstract class AbsMsgrActy : FlutterFragmentActivity(), RetryByHandler, Tag {
    val TAG by lazy { tag() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // tryOrRebind()
    }

    override fun onDestroy() {
        // ensureUnbind()
        super.onDestroy()
    }

    abstract val serviceStarter: StartMe.MsgrSrvce

    abstract val msgrServiceClazz: Class<out AbsMsgrService>

    protected open fun onMsgChannelConnected() {
        val msg = Message.obtain()
        msg.what = 1234567
        val b = Bundle()
        b.putString("msg_key", ">>> 这是一个测试`请求`消息 >>>。")
        msg.obj = b
        sendMsg2Server(msg)
    }

    protected open fun onMsgChannelDisconnected() {}

    protected open fun handleServerMsg(msg: Message, handler: Handler) {
        when (msg.what) {
            7654321 -> {
                Log.i(
                    TAG, String.format(
                        "handleServerMsg | msg > what: %s, content: %s.",
                        msg.what, (msg.obj as Bundle).getString("msg_key")
                    )
                )
            }
            else -> {
            }
        }
    }

    private val msgHandler: Handler by lazy {
        class H : Handler() {
            override fun handleMessage(msg: Message) {
                if (isFinishing || isDestroyed) {
                    Log.w(
                        TAG,
                        String.format(
                            "msgHandler.handleMessage | BLOCKED. >>> finishing: %s, destroyed: %s.",
                            isFinishing,
                            isDestroyed
                        )
                    )
                } else handleServerMsg(msg, msgHandler)
            }
        }
        H()
    }

    @Volatile
    private var sender: Messenger? = null

    @Volatile
    private var replyTo: Messenger? = null

    @Volatile
    private var connected: Boolean = false

    fun isChannelConnected() = connected

    fun sendMsg2Server(msg: Message) {
        fun shouldFinish() = isFinishing || isDestroyed
        if (!shouldFinish()) msgHandler.post {
            retryForceful(1000) {
                val msgr = sender
                when {
                    msgr != null -> {
                        try {
                            msgr.send(msg)
                            true
                        } catch (ex: RemoteException) {
                            Log.e(TAG, "", ex)
                            if (!msgr.binder.pingBinder()) {
                                Log.e(TAG, "client ping to-server binder failed.")
                                tryOrRebind()
                                true // 中断 retry
                            } else false
                        }
                    }
                    shouldFinish() -> true /*中断*/
                    else -> false
                }
            }
        }
    }

    override val delayer: Retry.Delayer by lazy { this.delayerOf() }
    override fun delayerHandler(): Handler = msgHandler

    private
    val serviceConn: ServiceConnection by lazy {
        object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, service: IBinder) {
                if (BuildConfig.DEBUG && connected) {
                    error("测试 onServiceConnected 会不会重复多次")
                }
                sender = serviceStarter.binder2Sender(service)
                replyTo = serviceStarter.replyToClient(sender!!, msgHandler)
                if (replyTo != null) {
                    Log.e(TAG, "onServiceConnected | 正常建立连接 -->")
                    if (!connected) {
                        connected = true
                        Log.e(TAG, "onServiceConnected | 正常建立连接 | DONE.")
                        onMsgChannelConnected()
                    }
                } else {
                    Log.e(TAG, "onServiceConnected | bindService 失败")
                    tryOrRebind()
                }
            }

            override fun onServiceDisconnected(name: ComponentName) {
                Log.e(TAG, "onServiceDisconnected | 断开连接 -->")
                if (ensureUnbind()) tryOrRebind()
                else {
                    // 说明是 force unbind, 正常。
                }
            }
        }
    }

    protected fun tryOrRebind() {
        ensureUnbind()
        serviceStarter.bind(this, serviceConn, msgrServiceClazz)
    }

    protected fun ensureUnbind(): Boolean = if (connected) {
        connected = false
        Log.e(TAG, "ensureUnbind | 断开连接 | DONE.")
        onMsgChannelDisconnected()
        serviceStarter.unReplyToClient(sender!!, replyTo!!)
        serviceStarter.unbind(this, serviceConn)
        sender = null
        replyTo = null
        true
    } else false
}
