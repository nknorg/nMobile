package hobby.wei.c.core

import android.app.Activity
import android.content.Context
import android.os.Looper
import android.view.Gravity
import android.widget.Toast
import org.nkn.mobile.app.App

/**
 * @author Chenai Nakam(chenai.nakam@gmail.com)
 * @version 1.0, 20/06/2018
 */
object toast {
    fun show(
        ctx: Context,
        s: CharSequence,
        long: Boolean = false,
        gravity: Int = Gravity.CENTER,
        xOffset: Int = 0,
        yOffset: Int = 0
    ) {
        val runnable = Runnable {
            val toast = Toast.makeText(ctx, s, if (long) Toast.LENGTH_LONG else Toast.LENGTH_SHORT)
            if (gravity != -1) toast.setGravity(gravity, xOffset, yOffset)
            toast.show()
        }

        if (Looper.getMainLooper().isCurrentThread) runnable.run()
        else if (ctx is Activity) ctx.runOnUiThread(runnable)
        else App.get().handler.post(runnable)
    }
}
