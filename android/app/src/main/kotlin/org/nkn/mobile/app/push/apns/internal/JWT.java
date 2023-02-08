package org.nkn.mobile.app.push.apns.internal;

import android.os.Build;

import androidx.annotation.RequiresApi;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.KeyFactory;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.SignatureException;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.KeySpec;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;

public final class JWT {

    /**
     * Generates a JWT token as per Apple's specifications.
     *
     * @param teamID The team ID (found in the member center)
     * @param keyID  The key ID (found when generating your private key)
     * @param secret The private key (excluding the header and the footer)
     * @return The resulting token, which will be valid for one hour
     * @throws InvalidKeySpecException  if the key is incorrect
     * @throws NoSuchAlgorithmException if the key algo failed to load
     * @throws InvalidKeyException      if the key is invalid
     * @throws SignatureException       if this signature object is not initialized properly.
     */
    @RequiresApi(api = Build.VERSION_CODES.O)
    public static String getToken(final String teamID, final String keyID, final String secret)
            throws InvalidKeySpecException, NoSuchAlgorithmException, InvalidKeyException, SignatureException {
        final int now = (int) (System.currentTimeMillis() / 1000);
        final String header = "{\"alg\":\"ES256\",\"kid\":\"" + keyID + "\"}";
        final String payload = "{\"iss\":\"" + teamID + "\",\"iat\":" + now + "}";

        final String part1 = Base64.getUrlEncoder().encodeToString(header.getBytes(StandardCharsets.UTF_8))
                + "."
                + Base64.getUrlEncoder().encodeToString(payload.getBytes(StandardCharsets.UTF_8));

        return part1 + "." + ES256(secret, part1);
    }

    /**
     * Adopted from http://stackoverflow.com/a/20322894/2274894
     *
     * @param secret The secret
     * @param data   The data to be encoded
     * @return The encoded token
     * @throws InvalidKeySpecException  if the key is incorrect
     * @throws NoSuchAlgorithmException if the key algo failed to load
     * @throws InvalidKeyException      if the key is invalid
     * @throws SignatureException       if this signature object is not initialized properly.
     */
    @RequiresApi(api = Build.VERSION_CODES.O)
    private static String ES256(final String secret, final String data)
            throws NoSuchAlgorithmException, InvalidKeySpecException, InvalidKeyException, SignatureException {

        KeyFactory kf = KeyFactory.getInstance("EC");
        KeySpec keySpec = new PKCS8EncodedKeySpec(Base64.getDecoder().decode(secret.getBytes()));
        PrivateKey key = kf.generatePrivate(keySpec);

        final Signature sha256withECDSA = Signature.getInstance("SHA256withECDSA");
        sha256withECDSA.initSign(key);

        sha256withECDSA.update(data.getBytes(StandardCharsets.UTF_8));

        final byte[] signed = sha256withECDSA.sign();
        return Base64.getUrlEncoder().encodeToString(signed);
    }
}
