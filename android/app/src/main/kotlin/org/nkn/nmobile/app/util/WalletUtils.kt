package org.nkn.nmobile.app.util

class WalletUtils {
    companion object {

        private const val ADDRESS_PATTERN = "NKN[0-9A-Za-z]{33}"
        private const val SEED_PATTERN = "[0-9A-Fa-f]{64}"
        private const val PUBKEY_PATTERN = SEED_PATTERN
        private const val AMOUNT_PATTERN = "(([1-9]\\d*)|0)(\\.(\\d{1,8}))?"

        fun isValidPubkey(pubkey: String?): Boolean {
            return pubkey?.matches(Regex(PUBKEY_PATTERN)) ?: false
        }

        fun isValidAddress(address: String?): Boolean {
            return address?.matches(Regex(ADDRESS_PATTERN)) ?: false
        }

        fun isValidSeed(seed: String?): Boolean {
            return seed?.matches(Regex(SEED_PATTERN)) ?: false
        }

        fun isValidAmount(amount: String): Boolean {
            return amount.matches(Regex(AMOUNT_PATTERN)) && if (amount.indexOf('.') > 0) {
                val index = amount.indexOf('.')
                amount.substring(index + 1).any { it.toInt() > 0 }
            } else true
        }

    }

}