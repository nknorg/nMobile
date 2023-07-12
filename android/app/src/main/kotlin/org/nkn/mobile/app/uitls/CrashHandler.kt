//package org.nkn.mobile.app.uitls
//
//import android.annotation.SuppressLint
//import android.content.Context
//import io.sentry.Sentry
//
//class CrashHandler private constructor(private val mContext: Context) : Thread.UncaughtExceptionHandler {
//    private var mHandlerListener: UncaughtExceptionHandlerListener? = null
//    private val sb: StringBuffer? = null
//
//    init {
//        Thread.setDefaultUncaughtExceptionHandler(this)
//    }
//
//    /* (non-Javadoc)
//     * @see java.lang.Thread.UncaughtExceptionHandler#uncaughtException(java.lang.Thread, java.lang.Throwable)
//     */
//    override fun uncaughtException(thread: Thread, ex: Throwable) {
//        handleException(ex)
//        mHandlerListener?.handlerUncaughtException(sb)
//    }
//
//    fun setHandlerListener(handlerListener: UncaughtExceptionHandlerListener?) {
//        mHandlerListener = handlerListener
//    }
//
//    private fun handleException(ex: Throwable?) {
//        if (ex == null) return
//        Sentry.captureException(ex)
//    }
//
//    interface UncaughtExceptionHandlerListener {
//        fun handlerUncaughtException(sb: StringBuffer?)
//    }
//
//    companion object {
//        @SuppressLint("StaticFieldLeak")
//        private var sInstance: CrashHandler? = null
//        fun getInstance(context: Context): CrashHandler? {
//            if (sInstance == null) {
//                sInstance = CrashHandler(context)
//            }
//            return sInstance
//        }
//    }
//}