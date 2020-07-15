/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app

import hobby.wei.c.persist.ModularStorer
import hobby.wei.c.persist.noUser
import org.nkn.mobile.app.abs.Tag

/**
 * @author Wei.Chou
 * @version 1.0, 03/03/2020
 */
object GlobalConf : Tag {
    val TAG by lazy { tag() }

    private const val MODULAR_STORED_GLOBAL_STATE = "stored_global_state"

    val STATE: StateStorer by lazy {
        ModularStorer.get(noUser.toString(), MODULAR_STORED_GLOBAL_STATE, clearable = false) {
            it.bind(StateStorer())
        }
    }

    class StateStorer : ModularStorer() {
        companion object {
            private const val KEY_LANGUAGE_LOCALE = "language_locale"
            private const val KEY_PUSH_NOTIFICATION_STATE = "key.push_notification_state"
            private const val KEY_REGISTERED_MESSAGING_CALLBACK_IDs = "key.registered_messaging_callback_ids"
        }

        //******************************************************//
        fun storeLanguageLocale(displayName: String) {
            get().storeString(KEY_LANGUAGE_LOCALE, displayName)
        }

        fun getLanguageLocale(default: String): String = get().loadString(KEY_LANGUAGE_LOCALE, default)

        fun clearLanguageLocale() {
            get().remove(KEY_LANGUAGE_LOCALE)
        }

        //******************************************************//
        fun storePushNotificationSetting(value: Int) {
            get().storeInt(KEY_PUSH_NOTIFICATION_STATE, value)
        }

        fun getPushNotificationSetting(default: Int): Int = get().loadInt(KEY_PUSH_NOTIFICATION_STATE, default)

        fun clearPushNotificationSetting() {
            get().remove(KEY_PUSH_NOTIFICATION_STATE)
        }

        //******************************************************//
        fun storeRegisteredMsgCallbackIds(value: List<String>) {
            get().storeString(KEY_REGISTERED_MESSAGING_CALLBACK_IDs, value.joinToString(":"))
        }

        fun getRegisteredMsgCallbackIds(default: List<String> = emptyList()): List<String> {
            val listStr = get().loadString(KEY_REGISTERED_MESSAGING_CALLBACK_IDs)
            return listStr?.split(':') ?: default
        }

        fun clearRegisteredMsgCallbackIds() {
            get().remove(KEY_REGISTERED_MESSAGING_CALLBACK_IDs)
        }
    }
}
