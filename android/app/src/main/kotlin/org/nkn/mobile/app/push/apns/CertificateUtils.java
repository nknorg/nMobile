package org.nkn.mobile.app.push.apns;

import org.nkn.mobile.app.push.apns.exceptions.CertificateEnvironmentMismatchException;

import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.HashMap;
import java.util.Map;

/**
 * Utilities around .p12 certificates.
 */
public class CertificateUtils {
    /**
     * Split the subject into it's components such as UID, C, OU, CN.
     * <p>
     * Example:
     * {UID=com.wizrocket.BeardedRobot, C=US, OU=PNEY234A6B, CN=Apple Production IOS Push Services: com.wizrocket.BeardedRobot}
     *
     * @param certificate The certificate
     * @param password    The password
     * @return A map containing the components of the subject
     * @throws CertificateException     if any of the certificates in the keystore could not be loaded
     * @throws NoSuchAlgorithmException if the algorithm used to check the integrity of the keystore cannot be found
     * @throws IOException              if there is an I/O or format problem with the keystore data,
     *                                  if a password is required but not given, or if the given password was incorrect
     * @throws KeyStoreException        if no Provider supports a KeyStoreSpi implementation for the specified type
     */
    public static Map<String, String> splitCertificateSubject(InputStream certificate, String password)
            throws KeyStoreException, CertificateException, NoSuchAlgorithmException, IOException {
        String subject = getCertificate(certificate, password).getSubjectDN().getName();
        return splitCertificateSubject(subject);
    }

    /**
     * Reads the certificate from the input stream, and returns an instance of X509Certificate.
     *
     * @param certificate The certificate
     * @param password    The password
     * @return The certificate
     * @throws CertificateException     if any of the certificates in the keystore could not be loaded
     * @throws NoSuchAlgorithmException if the algorithm used to check the integrity of the keystore cannot be found
     * @throws IOException              if there is an I/O or format problem with the keystore data,
     *                                  if a password is required but not given, or if the given password was incorrect
     * @throws KeyStoreException        if no Provider supports a KeyStoreSpi implementation for the specified type
     */
    public static X509Certificate getCertificate(InputStream certificate, String password)
            throws CertificateException, NoSuchAlgorithmException, IOException, KeyStoreException {
        password = password == null ? "" : password;
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(certificate, password.toCharArray());

        return (X509Certificate) ks.getCertificate(ks.aliases().nextElement());
    }

    /**
     * Split the subject into it's components such as UID, C, OU, DN.
     * <p>
     * Example:
     * {UID=com.wizrocket.BeardedRobot, C=US, OU=PNEY234A6B, CN=Apple Production IOS Push Services: com.wizrocket.BeardedRobot}
     *
     * @param subject The subject of the certificate
     * @return A map containing the components of the subject
     */
    @SuppressWarnings("WeakerAccess")
    public static Map<String, String> splitCertificateSubject(String subject) {
        HashMap<String, String> map = new HashMap<>();
        if (subject != null) {
            String[] parts = subject.split(",");
            for (String part : parts) {
                String[] kv = part.split("=");
                if (kv.length != 2) continue;

                map.put(kv[0].trim(), kv[1].trim());
            }
        }
        return map;
    }

    /**
     * Checks a certificate for it's validity, as well as that it's a push certificate.
     *
     * @param production  Validate the certificate environment, if required
     * @param certificate The certificate to be validated
     * @throws CertificateException When the certificate is not valid, or if it's expired,
     *                              or if it's not a push certificate
     */
    public static void validateCertificate(boolean production, X509Certificate certificate)
            throws CertificateException {
        if (certificate == null) throw new CertificateException("Null certificate");

        // Test for it's validity
        certificate.checkValidity();

        // Ensure that it's a push certificate
        final Map<String, String> stringStringMap = CertificateUtils.splitCertificateSubject(certificate.getSubjectDN().getName());
        final String cn = stringStringMap.get("CN");
        if (!cn.toLowerCase().contains("push")) {
            throw new CertificateException("Not a push certificate - " + cn);
        }

        if (production && cn.toLowerCase().contains("apple development ios push services")) {
            throw new CertificateEnvironmentMismatchException("Invalid environment for this certificate");
        } else if (!production && cn.toLowerCase().contains("apple production ios push services")) {
            throw new CertificateEnvironmentMismatchException("Invalid environment for this certificate");
        }
    }
}
