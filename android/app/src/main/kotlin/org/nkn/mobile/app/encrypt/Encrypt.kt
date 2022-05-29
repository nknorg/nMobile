package org.nkn.mobile.app.encrypt

import android.os.Build
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object Encrypt {
    /*private fun randomKey(bits: Int): SecretKeySpec? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && (bits % 8 == 0)) {
            return try {
                val secureRandom = SecureRandom()
                val iv = ByteArray(bits / 8)
                secureRandom.nextBytes(iv)
                return SecretKeySpec(iv, KeyProperties.KEY_ALGORITHM_AES)
            } catch (e: Exception) {
                Log.e("Encrypt", "randomKey - error: ${e.message}")
                null
            }
        }
        return null
    }

    private fun generateKey(key: ByteArray?): SecretKeySpec? {
        if (key == null || key.isEmpty()) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return try {
                SecretKeySpec(key, KeyProperties.KEY_ALGORITHM_AES)
            } catch (e: Exception) {
                Log.e("Encrypt", "generateKey - error: ${e.message}")
                null
            }
        }
        return null
    }

    fun encrypt(algorithm: String, bits: Int, data: ByteArray): Map<String, Any>? {
        if (algorithm.isEmpty() || (bits % 8 != 0) || data.isEmpty()) return null
        val key: SecretKeySpec = randomKey(bits) ?: return null
        return try {
            val cipher: Cipher = Cipher.getInstance(algorithm)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val cipherText = cipher.doFinal(data)
            // val cipherText = result.copyOfRange(0, result.size - bits / 8)
            // val tag = result.copyOfRange(result.size - bits / 8, result.size)

            val iv = cipher.iv.copyOf()
            val result = HashMap<String, Any>()
            result["algorithm"] = algorithm
            result["bits"] = bits
            result["key_bytes"] = key.encoded
            result["iv_bytes"] = iv
            result["cipher_text_bytes"] = cipherText
            result
        } catch (e: Exception) {
            Log.e("Encrypt", "encrypt - error: ${e.message}")
            null
        }
    }

    fun decrypt(algorithm: String, bits: Int, keyBytes: ByteArray, ivBytes: ByteArray, data: ByteArray): ByteArray? {
        if (algorithm.isEmpty() || (bits % 8 != 0) || keyBytes.isEmpty() || data.isEmpty()) return null
        val key: SecretKeySpec = generateKey(keyBytes) ?: return null
        return try {
            val cipher = Cipher.getInstance(algorithm)
            val gcmSpec = GCMParameterSpec(bits, ivBytes)
            cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec)
            cipher.doFinal(data)
        } catch (e: Exception) {
            Log.e("Encrypt", "decrypt - error: ${e.message}")
            null
        }
    }*/
}
