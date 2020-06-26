/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.abs

import android.app.Activity
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.*
import android.util.Log
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity

/**
 * @author Wei.Chou
 * @version 1.0, 06/02/2020
 */
object StartMe {
    interface Const {
        val MSG_REPLY_TO: Int //= 999999999
        val MSG_UN_REPLY: Int

        val CMD_EXTRA_STOP_SERVICE: String //= getApp.withPackageNamePrefix("CMD_EXTRA_STOP_SERVICE")
        val CMD_EXTRA_START_FOREGROUND: String
        val CMD_EXTRA_STOP_FOREGROUND: String
    }

    interface MsgrSrvce : Const {
        fun <S : Service> start(ctx: Context, clazz: Class<S>) {
            ctx.startService(Intent(ctx, clazz))
        }

        fun <S : Service> startFg(ctx: Context, clazz: Class<S>) {
            val intent = Intent(ctx, clazz)
            intent.putExtra(CMD_EXTRA_START_FOREGROUND, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }
        }

        fun <S : Service> stopFg(ctx: Context, clazz: Class<S>) {
            val intent = Intent(ctx, clazz)
            intent.putExtra(CMD_EXTRA_STOP_FOREGROUND, true)
            ctx.startService(intent)
        }

        /**
         * 停止`clazz`参数指定的`Service`（发送一个请求让其自己关闭，而不是直接`stopService()`）。
         * <p>
         * 几种`stopService`方法的异同：
         * <br>
         * 1. `Context.stopService()`
         * 不论之前调用过多少次`startService()`，都会在调用一次本语句后关闭`Service`，
         * 但是如果有还没断开的`bind`连接，则会一直等到全部断开后自动关闭`Service`；
         * <br>
         * 2. `Service.stopSelf()`完全等同于`Context.stopService()`；
         * <br>
         * 3. `stopSelfResult(startId)`
         * 只有`startId`是最后一次`onStartCommand()`所传来的时，才会返回`true`并执行与`stopSelf()`相同的操作；
         * <br>
         * 4. `stopSelf(startId)`等同于`stopSelfResult(startId)`，只是没有返回值。
         */
        fun <S : Service> stop(ctx: Context, clazz: Class<S>) {
            val intent = Intent(ctx, clazz)
            intent.putExtra(CMD_EXTRA_STOP_SERVICE, true)
            ctx.startService(intent)
        }

        fun <S : Service> bind(ctx: Context, conn: ServiceConnection, clazz: Class<S>) {
            start(ctx, clazz)
            ctx.bindService(Intent(ctx, clazz), conn, Context.BIND_AUTO_CREATE)
        }

        fun unbind(ctx: Context, conn: ServiceConnection) {
            try { // 如果Service已经被系统销毁，则这里会出现异常。
                ctx.unbindService(conn)
            } catch (e: Exception) {
                Log.i("unbind", "", e)
            }
        }

        /**
         * 生成能够向`Service`端传递消息的信使对象。
         *
         * @param service `bindService()`之后通过回调传回来的调用通道`IBinder`（详见`ServiceConnection`）。
         * @return 向`Service`端传递消息的信使对象。
         */
        fun binder2Sender(service: IBinder): Messenger = Messenger(service)

        /**
         * `Client`端调用本方法以使`Service`端可以向`Client`发送`Message`。
         *
         * @param sender  `Client`取得的面向`Service`的信使对象。
         * @param handler `Client`用来处理`Service`发来的`Message`的`Handler`。
         * @return 建立信使是否成功。
         */
        fun replyToClient(sender: Messenger, handler: Handler): Messenger? {
            val msg = Message.obtain()
            msg.what = MSG_REPLY_TO
            msg.replyTo = Messenger(handler)
            return try {
                sender.send(msg)
                msg.replyTo
            } catch (e: RemoteException) {
                null
            }
        }

        fun unReplyToClient(sender: Messenger, replyTo: Messenger) {
            val msg = Message.obtain()
            msg.what = MSG_UN_REPLY
            msg.replyTo = replyTo
            try {
                sender.send(msg)
            } catch (e: RemoteException) {
            }
        }
    }

    interface Acty {
        fun startMe(ctx: Context, intent: Intent, options: Bundle?) {
            startMe(ctx, intent, false, 0, options)
        }

        fun startMe(
            context: Context,
            intent: Intent,
            forResult: Boolean = false,
            requestCode: Int = 0,
            options: Bundle? = null
        ) {
            if (forResult) {
                require(context is Activity)
                context.startActivityForResult(intent, requestCode, options)
            } else {
                if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent, options)
            }
        }
    }

    interface Fragmt {
        fun startMe(fragmt: Fragment, intent: Intent, options: Bundle?) {
            startMe(fragmt, intent, false, 0, options)
        }

        fun startMe(
            fragmt: Fragment,
            intent: Intent,
            forResult: Boolean = false,
            requestCode: Int = 0,
            options: Bundle? = null
        ) {
            if (forResult) {
                fragmt.startActivityForResult(intent, requestCode, options)
            } else {
                fragmt.startActivity(intent, options)
            }
        }
    }
}
