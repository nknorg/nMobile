package org.nkn.mobile.app.uitls

import android.app.Activity
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.view.View
import android.view.Window
import android.view.WindowManager

class BlurWindow(activity: Activity) {

    companion object {
        const val START_BLUR = 0
        const val STOP_BLUR = 1
        private const val EMPTY_SIZE = 0
        private var MASK_WIDTH = 0
        private var MASK_HEIGHT = 0
    }

    private val mWindow: Window = activity.window
    private val mWindowManager: WindowManager = mWindow.windowManager
    private var mEmptyView: View = View(activity)

    private val mHandler: Handler = object : Handler(Looper.getMainLooper()) {
        private var isAdd = false
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                START_BLUR -> if (!isAdd) {
                    val lp: WindowManager.LayoutParams = WindowManager.LayoutParams()
                    lp.flags = lp.flags or (WindowManager.LayoutParams.FLAG_BLUR_BEHIND or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
                    lp.format = PixelFormat.TRANSPARENT
                    lp.width = MASK_WIDTH
                    lp.height = MASK_HEIGHT
                    lp.type = WindowManager.LayoutParams.TYPE_APPLICATION
                    if (!mEmptyView.isAttachedToWindow) {
                        mWindowManager.addView(mEmptyView, lp)
                    }
                    isAdd = true
                }
                STOP_BLUR -> {
                    if (mEmptyView.isAttachedToWindow) {
                        mWindowManager.removeView(mEmptyView)
                    }
                    isAdd = false
                }
                else -> {
                    // nothing
                }
            }
        }
    }

    fun startBlur() {
        mHandler.sendEmptyMessage(START_BLUR)
    }

    fun stopBLur() {
        mHandler.sendEmptyMessage(STOP_BLUR)
    }

    /*init {
        mEmptyView.setBackgroundColor(Color.BLUE)
        mEmptyView.isSaveEnabled = true
        mEmptyView.isSaveFromParentEnabled = true
        val resources: Resources = activity.resources
        val dm: DisplayMetrics = resources.displayMetrics
        MASK_WIDTH = dm.widthPixels
        MASK_HEIGHT = dm.heightPixels

        val lp: WindowManager.LayoutParams = WindowManager.LayoutParams()
        lp.flags = lp.flags or (WindowManager.LayoutParams.FLAG_BLUR_BEHIND or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
        lp.format = PixelFormat.TRANSPARENT
        lp.width = MASK_WIDTH
        lp.height = MASK_HEIGHT
        lp.type = WindowManager.LayoutParams.TYPE_APPLICATION
        if (!mEmptyView.isAttachedToWindow) {
            mWindowManager.addView(mEmptyView, lp)
            mWindowManager.updateViewLayout(mEmptyView, lp)
        }
    }*/
}
