package org.nkn.mobile.app.push.apns.exceptions;

import java.security.cert.CertificateException;

/**
 * Thrown when a development certificate has been uploaded and
 * the environment has been set to production, or vice versa.
 */
public class CertificateEnvironmentMismatchException extends CertificateException {

    public CertificateEnvironmentMismatchException(String s) {
        super(s);
    }
}
