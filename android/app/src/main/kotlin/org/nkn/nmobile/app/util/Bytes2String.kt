package org.nkn.mobile.app.util

import android.util.Base64
import org.bouncycastle.jcajce.provider.digest.MD5
import org.bouncycastle.jcajce.provider.digest.SHA256
import org.bouncycastle.util.encoders.Hex

object Bytes2String {
    fun ByteArray.toBase64(flags: Int = Base64.NO_WRAP) = Base64.encodeToString(this, flags)
    fun String.decodeBase64(flags: Int = Base64.NO_WRAP) = Base64.decode(this, flags)

    fun String.toBase64(flags: Int = Base64.NO_WRAP) = Base64.encodeToString(this.toByteArray(), flags)
    fun String.decodeBase64asString(flags: Int = Base64.NO_WRAP) = String(Base64.decode(this, flags))

    fun ByteArray.toHex() = Hex.toHexString(this)
    fun String.decodeHex(): ByteArray = Hex.decode(this)

    fun ByteArray.toSha256() = SHA256.Digest().digest(this)
    fun ByteArray.toMd5() = MD5.Digest().digest(this)

    fun String.suffix() = this.substring(this.lastIndexOf('.') + 1)


    fun String.withAndroidPrefix() = "ANDROID | " + this
}
