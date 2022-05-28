//
//  encrypt.swift
//  Runner
//
//  Created by 蒋治国 on 2022/5/26.
//

import Foundation
import CryptoSwift

public class Encrypt {
    
    static func randomKey(bits: Int) -> Data? {
        guard (bits % 8 == 0) else {
            return nil
        }
        var generatedRandom = Data(count: bits / 8)
        let randomGenerationStatus = generatedRandom.withUnsafeMutableBytes { mutableRandomBytes in
            // Force unwrapping is ok, since the buffer is guaranteed not to be empty.
            // From the docs: If the baseAddress of this buffer is nil, the count is zero.
            // swiftlint:disable:next force_unwrapping
            SecRandomCopyBytes(kSecRandomDefault, bits / 8, mutableRandomBytes.baseAddress!)
        }
        guard randomGenerationStatus == errSecSuccess else {
            return nil
        }
        return generatedRandom
    }

    static func generateKey(key: Data) -> Data? {
        return key
    }

    static func encrypt(algorithm: String, bits: Int, data: Data) -> [String: Any]? {
        do {
            // In combined mode, the authentication tag is directly appended to the encrypted message. This is usually what you want.
            if(algorithm.lowercased().contains("gcm")) {
                let key = randomKey(bits: bits)
                if(key == nil) {
                    return nil
                }
                let iv = AES.randomIV(bits / 8)
                let gcm = GCM(iv: iv, mode: .combined)
                let aes = try AES(key: key!.bytes, blockMode: gcm, padding: algorithm.lowercased().contains("nopadding") ? .noPadding : .zeroPadding)
                let aaa = data.bytes
                let cipherText = try aes.encrypt(aaa)
                // let tag = gcm.authenticationTag

                var resp: [String: Any] = [String: Any]()
                resp["algorithm"] = algorithm
                resp["bits"] = bits
                resp["key_bytes"] = Data(key!)
                resp["iv_bytes"] = Data(iv)
                resp["cipher_text_bytes"] =  Data(cipherText)
                return resp
            }
        } catch {
            print("Encrypt - encrypt fail")
        }
        return nil
    }
    
    static func decrypt(algorithm: String, bits: Int, keyBytes: Data, ivBytes: Data, data: Data) -> Data? {
        do {
            let key = generateKey(key: keyBytes)
            if(key == nil) {
                return nil
            }
            let gcm = GCM(iv: ivBytes.bytes, mode: .combined)
            let aes = try AES(key: key!.bytes, blockMode: gcm, padding: algorithm.lowercased().contains("nopadding") ? .noPadding : .zeroPadding)
            return try Data(aes.decrypt(data.bytes))
        } catch {
            print("Encrypt - decrypt fail")
        }
        return nil
    }
}
