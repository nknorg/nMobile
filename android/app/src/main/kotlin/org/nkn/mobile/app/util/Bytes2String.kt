/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

package org.nkn.mobile.app.util

import android.util.Base64
import org.bouncycastle.jcajce.provider.digest.MD5
import org.bouncycastle.jcajce.provider.digest.SHA1
import org.bouncycastle.jcajce.provider.digest.SHA256
import org.bouncycastle.util.encoders.Hex
import java.io.File

/**
 * @author Wei.Chou
 * @version 1.0, 10/03/2020
 */
object Bytes2String {
    fun ByteArray.toBase64(flags: Int = Base64.NO_WRAP) = Base64.encodeToString(this, flags)
    fun String.decodeBase64(flags: Int = Base64.NO_WRAP) = Base64.decode(this, flags)

    fun String.toBase64(flags: Int = Base64.NO_WRAP) = Base64.encodeToString(this.toByteArray(), flags)
    fun String.decodeBase64asString(flags: Int = Base64.NO_WRAP) = String(Base64.decode(this, flags))

    fun ByteArray.toHex() = Hex.toHexString(this)
    fun String.decodeHex(): ByteArray = Hex.decode(this)

    fun ByteArray.toSha256() = SHA256.Digest().digest(this)
    fun ByteArray.toMd5() = MD5.Digest().digest(this)
    fun ByteArray.toSha1() = SHA1.Digest().digest(this)

    fun String.suffix(): String? {
        val i = this.lastIndexOf('.')
        val k = this.lastIndexOf(File.separatorChar)
        return if (i > k) this.substring(i + 1) else null
    }

    fun String.dropn(c: Char): String {
        return if (!this.startsWith(c)) this
        else this.substring(1).dropn(c)
    }

    fun String.withAndroidPrefix(): String {
        return "ANDROID | " + this
    }
}
