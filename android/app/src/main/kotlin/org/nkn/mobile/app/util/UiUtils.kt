/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.util

import android.content.Context
import android.util.Log
import android.util.TypedValue

/**
 * @author Wei.Chou
 * @version 1.0, 19/02/2020
 */
object UiUtils {
    fun dp2px(context: Context, value: Float): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.resources.displayMetrics
        )

    fun dp2pxOffset(context: Context, value: Float): Int = dp2px(context, value).toInt()

    fun dp2pxSize(context: Context, value: Float): Int {
        val f = dp2px(context, value)
        val res: Int = (if (f >= 0) f + 0.5f else f - 0.5f).toInt()
        if (res != 0) return res
        if (value == 0f) return 0
        if (value > 0) return 1
        return -1
    }

    fun sp2px(context: Context, value: Float): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            value,
            context.resources.displayMetrics
        )

    fun sp2pxOffset(context: Context, value: Float): Int = sp2px(context, value).toInt()

    fun sp2pxSize(context: Context, value: Float): Int {
        val f = sp2px(context, value)
        val res: Int = (if (f >= 0) f + 0.5f else f - 0.5f).toInt()
        if (res != 0) return res
        if (value == 0f) return 0
        if (value > 0) return 1
        return -1
    }

    fun getStatusBarHeight(context: Context): Int {
        return try {
            context.resources.getDimensionPixelSize(
                IdGetter.getIdSys(context, R_ID_STATUS_BAR_HEIGHT, IdGetter.dimen)
            )
        } catch (e: Exception) {
            Log.e("getStatusBarHeight", e.message, e)
            dp2pxSize(context, 24f)
        }
    }

    private const val R_ID_STATUS_BAR_HEIGHT = "status_bar_height"
}
