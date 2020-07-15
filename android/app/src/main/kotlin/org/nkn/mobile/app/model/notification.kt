/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.model

import org.nkn.mobile.app.GlobalConf

/**
 * @author Wei.Chou
 * @version 1.0, 31/03/2020
 */
object notification {
    sealed class EffectType(val value: Int) {
        object Mute : EffectType(1)
        object Sound : EffectType(2)
        object Vibration : EffectType(3)
        object SoundVibra : EffectType(4)
        object Desabled : EffectType(0)

        companion object {
            fun retrieve(value: Int): EffectType {
                return when (value) {
                    Desabled.value -> Desabled
                    Mute.value -> Mute
                    Sound.value -> Sound
                    Vibration.value -> Vibration
                    SoundVibra.value -> SoundVibra
                    else -> Vibration
                }
            }
        }
    }

    fun saveSetting(type: EffectType) {
        GlobalConf.STATE.storePushNotificationSetting(type.value)
    }

    fun getSetting(): EffectType = EffectType.retrieve(GlobalConf.STATE.getPushNotificationSetting(-1))
}
