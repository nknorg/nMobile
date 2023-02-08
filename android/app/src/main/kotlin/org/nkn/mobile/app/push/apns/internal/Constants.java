package org.nkn.mobile.app.push.apns.internal;

import java.nio.charset.Charset;

/**
 * Internal constants used by this library.
 */
public class Constants {
    public static final Charset UTF_8 = Charset.forName("UTF-8");
    public static final String ENDPOINT_PRODUCTION = "https://api.push.apple.com";
    public static final String ENDPOINT_SANDBOX = "https://api.sandbox.push.apple.com";
}
