package org.nkn.mobile.app.util

import java.math.BigDecimal
import java.text.DecimalFormat

object NumberFormatter {
    fun format(number: Float): String = default.format(BigDecimal(number.toString()))
    fun format(number: Double): String = default.format(BigDecimal(number.toString()))
    fun format(number: Any): String =
        if (number is String) default.format(BigDecimal(number)) else default.format(number)

    val default by lazy { getFormatter(3, 8, 0) }

    fun getFormatter(group: Int, maxFrac: Int, minFrac: Int): DecimalFormat {
        val f = DecimalFormat()
        f.groupingSize = group
        f.maximumFractionDigits = maxFrac
        f.minimumFractionDigits = minFrac
        return f
    }
}
