/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.dchat

import android.os.Bundle
import android.os.Handler
import android.os.Message
import nkn.Account
import nkn.Nkn

/**
 * @author Wei.Chou
 * @version 1.0, 26/03/2020
 */
object Msgs {
    const val MSG_NKN_ACCOUNT = 0
    const val MSG_WAKEUP = 1
    const val MSG_CONNECTION_CONNECTED = 2
    const val MSG_CONNECTION_DISCONNECT = 3
    const val MSG_CONNECTION_STATE = 4
    const val MSG_SEND_MESSAGE_STD = 12

    const val KEY_NKN_ACCOUNT = "key.nkn_account"
    const val KEY_CHAT_ID = "key.chat_id"
    const val KEY_MESSAGE_STD = "key.message_std"

    interface Req {
        /**
         * @param handler But this `handler` is on the main thread.
         */
        fun handleServerMsg(msg: Message, handler: Handler, callback: Callback): Boolean {
            when (msg.what) {
                MSG_CONNECTION_CONNECTED -> {
                    callback.onConnectionChanged(true)
                }
                MSG_CONNECTION_DISCONNECT -> {
                    callback.onConnectionChanged(false)
                }
                else -> return false
            }
            return true
        }

        interface Callback {
            fun onConnectionChanged(connected: Boolean)
        }

        fun buildMsg4SendAccount(account: Account? = null/*fore change account*/): Message {
            val msg = Message.obtain()
            msg.what = MSG_NKN_ACCOUNT
            if (account != null) {
                val bundle = Bundle()
                bundle.putByteArray(KEY_NKN_ACCOUNT, account.seed())
                msg.data = bundle
            }
            return msg
        }

        fun buildMsg4Wakeup(): Message {
            val msg = Message.obtain()
            msg.what = MSG_WAKEUP
            return msg
        }

        fun buildMsg4RetrieveConnectionState(): Message {
            val msg = Message.obtain()
            msg.what = MSG_CONNECTION_STATE
            return msg
        }

        fun buildMsg4SendMessageStd(chatIdReceiver: String, msgStdJson: String): Message {
            val msg = Message.obtain()
            msg.what = MSG_SEND_MESSAGE_STD
            val bundle = Bundle()
            bundle.putString(KEY_CHAT_ID, chatIdReceiver)
            bundle.putString(KEY_MESSAGE_STD, msgStdJson)
            msg.data = bundle
            return msg
        }
    }

    interface Resp {
        /**
         * @param handler Note: This `handler` is [NOT] on the main thread.
         */
        fun handleClientMsg(msg: Message, handler: Handler, service: DChatServiceForFlutter): Boolean {
            when (msg.what) {
                MSG_NKN_ACCOUNT -> {
                    val byteArray = msg.data.getByteArray(KEY_NKN_ACCOUNT)
                    service.onAccountGot(byteArray?.let { Nkn.newAccount(byteArray) })
                }
                MSG_WAKEUP -> {
                    service.wakeup()
                }
                MSG_CONNECTION_STATE -> {
                    service.feedbackConnectionState()
                }
                else -> return false
            }
            return true
        }

//        fun buildMsg4ObtainAccount(): Message {
//            val msg = Message.obtain()
//            msg.what = MSG_NKN_ACCOUNT
//            return msg
//        }

        fun buildMsg4ConnectionState(isConnected: Boolean): Message {
            val msg = Message.obtain()
            if (isConnected) msg.what = MSG_CONNECTION_CONNECTED
            else msg.what = MSG_CONNECTION_DISCONNECT
            return msg
        }
    }
}
