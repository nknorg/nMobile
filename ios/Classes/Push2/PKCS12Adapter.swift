import Foundation
import Security

enum PKCS12AdapterError: Error {
    case unknown
    case fileNotFound
    case fileOpenFailed
    case secAuthFailed
}

public struct PKCS12Adapter {
    
    public let secCertificate: SecCertificate
    public let secIdentity: SecIdentity
    
    public init(fileName: String, passPhrase: String) throws {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "p12") else {
            throw PKCS12AdapterError.fileNotFound
        }
        
        guard let pkcs12data = NSData(contentsOfFile: path) else {
            throw PKCS12AdapterError.fileOpenFailed
        }
        
        let options = [String(kSecImportExportPassphrase): passPhrase]
        var imported: CFArray? = nil
        
        switch SecPKCS12Import(pkcs12data, options as CFDictionary, &imported) {
        case noErr:
            let identityDictionaries = imported as! [[String:Any]]
            let identityRef = identityDictionaries[0][kSecImportItemIdentity as String] as! SecIdentity
            
            var _certRef: SecCertificate?
            SecIdentityCopyCertificate(identityRef, &_certRef)
            
            guard let certRef = _certRef else {
                throw PKCS12AdapterError.unknown
            }
            
            self.secCertificate = certRef
            self.secIdentity = identityRef
            
        case errSecAuthFailed:
            throw PKCS12AdapterError.secAuthFailed
            
        default:
            throw PKCS12AdapterError.unknown
        }
    }
    
    public var sslCertificates: [Any] {
        return [secIdentity, secCertificate]
    }
}
