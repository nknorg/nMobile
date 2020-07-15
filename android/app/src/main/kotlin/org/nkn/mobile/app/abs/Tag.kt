/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.abs

/**
 * @author Wei.Chou
 * @version 1.0, 07/02/2020
 */
interface Tag {
    fun tag(): String = tagInner(23, 3)

    fun unique(): String = tagInner(32, 5)

    private fun tagInner(length: Int, lenHashCode: Int): String {
        val name = javaClass.name
        val i = name.indexOf('$')
        val tag = name.substring(
            0, //name.lastIndexOf('.') + 1,
            if (i <= 0) name.length else i
            // companion object's hashCode() is different with [this.hashCode()]
        ) + sub2(i, name) + '@' + hashCode().toString().substring(0, lenHashCode)
        return if (tag.length <= length) tag else tag.substring(tag.length - length, tag.length)
    }

    private fun sub2(i: Int, name: String): String {
        val j by lazy { name.lastIndexOf('$') }
        return if (i <= 0) "" else name.substring(j, if (j + 3 > name.length) name.length else j + 3)
    }
}
