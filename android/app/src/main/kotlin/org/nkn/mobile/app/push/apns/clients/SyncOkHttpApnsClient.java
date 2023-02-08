package org.nkn.mobile.app.push.apns.clients;

import android.os.Build;

import org.nkn.mobile.app.push.apns.ApnsClient;
import org.nkn.mobile.app.push.apns.CertificateUtils;
import org.nkn.mobile.app.push.apns.internal.Constants;
import org.nkn.mobile.app.push.apns.internal.JWT;
import org.nkn.mobile.app.push.apns.notification.Notification;
import org.nkn.mobile.app.push.apns.notification.NotificationRequestError;
import org.nkn.mobile.app.push.apns.notification.NotificationResponse;
import org.nkn.mobile.app.push.apns.notification.NotificationResponseListener;

import java.io.IOException;
import java.io.InputStream;
import java.security.InvalidKeyException;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.SignatureException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.security.spec.InvalidKeySpecException;
import java.util.UUID;

import javax.net.ssl.KeyManager;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

import okhttp3.ConnectionPool;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okio.BufferedSink;

/**
 * A wrapper around OkHttp's http client to send out notifications using Apple's HTTP/2 API.
 */
public class SyncOkHttpApnsClient implements ApnsClient {

    private final String defaultTopic;
    private final String apnsAuthKey;
    private final String teamID;
    private final String keyID;
    protected final OkHttpClient client;
    private final String gateway;
    private static final MediaType mediaType = MediaType.parse("application/json");

    private long lastJWTTokenTS = 0;
    private String cachedJWTToken = null;

    /**
     * Creates a new client which uses token authentication API.
     *
     * @param apnsAuthKey   The private key - exclude -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
     * @param teamID        The team ID
     * @param keyID         The key ID (retrieved from the file name)
     * @param production    Whether to use the production endpoint or the sandbox endpoint
     * @param defaultTopic  A default topic (can be changed per message)
     * @param clientBuilder An OkHttp client builder, possibly pre-initialized, to build the actual client
     */
    public SyncOkHttpApnsClient(String apnsAuthKey, String teamID, String keyID, boolean production,
                                String defaultTopic, OkHttpClient.Builder clientBuilder) {
        this.apnsAuthKey = apnsAuthKey;
        this.teamID = teamID;
        this.keyID = keyID;
        client = clientBuilder.build();

        this.defaultTopic = defaultTopic;

        gateway = production ? Constants.ENDPOINT_PRODUCTION : Constants.ENDPOINT_SANDBOX;
    }

    /**
     * Creates a new client which uses token authentication API.
     *
     * @param apnsAuthKey    The private key - exclude -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
     * @param teamID         The team ID
     * @param keyID          The key ID (retrieved from the file name)
     * @param production     Whether to use the production endpoint or the sandbox endpoint
     * @param defaultTopic   A default topic (can be changed per message)
     * @param connectionPool A connection pool to use. If null, a new one will be generated
     */
    public SyncOkHttpApnsClient(String apnsAuthKey, String teamID, String keyID, boolean production,
                                String defaultTopic, ConnectionPool connectionPool) {

        this(apnsAuthKey, teamID, keyID, production, defaultTopic, getBuilder(connectionPool));
    }

    /**
     * Creates a new client and automatically loads the key store
     * with the push certificate read from the input stream.
     *
     * @param certificate  The client certificate to be used
     * @param password     The password (if required, else null)
     * @param production   Whether to use the production endpoint or the sandbox endpoint
     * @param defaultTopic A default topic (can be changed per message)
     * @param builder      An OkHttp client builder, possibly pre-initialized, to build the actual client
     * @throws UnrecoverableKeyException If the key cannot be recovered
     * @throws KeyManagementException    if the key failed to be loaded
     * @throws CertificateException      if any of the certificates in the keystore could not be loaded
     * @throws NoSuchAlgorithmException  if the algorithm used to check the integrity of the keystore cannot be found
     * @throws IOException               if there is an I/O or format problem with the keystore data,
     *                                   if a password is required but not given, or if the given password was incorrect
     * @throws KeyStoreException         if no Provider supports a KeyStoreSpi implementation for the specified type
     */
    public SyncOkHttpApnsClient(InputStream certificate, String password, boolean production,
                                String defaultTopic, OkHttpClient.Builder builder)
            throws CertificateException, NoSuchAlgorithmException, KeyStoreException,
            IOException, UnrecoverableKeyException, KeyManagementException {

        teamID = keyID = apnsAuthKey = null;

        password = password == null ? "" : password;
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(certificate, password.toCharArray());

        final X509Certificate cert = (X509Certificate) ks.getCertificate(ks.aliases().nextElement());
        CertificateUtils.validateCertificate(production, cert);

        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(ks, password.toCharArray());
        KeyManager[] keyManagers = kmf.getKeyManagers();
        SSLContext sslContext = SSLContext.getInstance("TLS");

        final TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init((KeyStore) null);
        sslContext.init(keyManagers, tmf.getTrustManagers(), null);

        final SSLSocketFactory sslSocketFactory = sslContext.getSocketFactory();

        builder.sslSocketFactory(sslSocketFactory, (X509TrustManager) tmf.getTrustManagers()[0]);

        client = builder.build();

        this.defaultTopic = defaultTopic;
        gateway = production ? Constants.ENDPOINT_PRODUCTION : Constants.ENDPOINT_SANDBOX;
    }

    /**
     * Creates a new client and automatically loads the key store
     * with the push certificate read from the input stream.
     *
     * @param certificate    The client certificate to be used
     * @param password       The password (if required, else null)
     * @param production     Whether to use the production endpoint or the sandbox endpoint
     * @param defaultTopic   A default topic (can be changed per message)
     * @param connectionPool A connection pool to use. If null, a new one will be generated
     * @throws UnrecoverableKeyException If the key cannot be recovered
     * @throws KeyManagementException    if the key failed to be loaded
     * @throws CertificateException      if any of the certificates in the keystore could not be loaded
     * @throws NoSuchAlgorithmException  if the algorithm used to check the integrity of the keystore cannot be found
     * @throws IOException               if there is an I/O or format problem with the keystore data,
     *                                   if a password is required but not given, or if the given password was incorrect
     * @throws KeyStoreException         if no Provider supports a KeyStoreSpi implementation for the specified type
     */
    public SyncOkHttpApnsClient(InputStream certificate, String password, boolean production,
                                String defaultTopic, ConnectionPool connectionPool)
            throws CertificateException, NoSuchAlgorithmException, KeyStoreException,
            IOException, UnrecoverableKeyException, KeyManagementException {

        this(certificate, password, production, defaultTopic, getBuilder(connectionPool));
    }

    /**
     * Creates a default builder that can be customized later and then passed to one of
     * the constructors taking a builder instance. The constructors that don't take
     * builders themselves use this method internally to create their client builders.
     *
     * @param connectionPool A connection pool to use. If null, a new one will be generated
     * @return a new OkHttp client builder, intialized with default settings.
     */
    private static OkHttpClient.Builder getBuilder(ConnectionPool connectionPool) {
        OkHttpClient.Builder builder = ApnsClientBuilder.createDefaultOkHttpClientBuilder();
        if (connectionPool != null) {
            builder.connectionPool(connectionPool);
        }

        return builder;
    }

    @Override
    public boolean isSynchronous() {
        return true;
    }

    @Override
    public void push(Notification notification, NotificationResponseListener listener) {
        throw new UnsupportedOperationException("Asynchronous requests are not supported by this client");
    }

    protected final Request buildRequest(Notification notification) {
        final String topic = notification.getTopic() != null ? notification.getTopic() : defaultTopic;
        final String collapseId = notification.getCollapseId();
        final UUID uuid = notification.getUuid();
        final long expiration = notification.getExpiration();
        final Notification.Priority priority = notification.getPriority();
        Request.Builder rb = new Request.Builder()
                .url(gateway + "/3/device/" + notification.getToken())
                .post(new RequestBody() {
                    @Override
                    public MediaType contentType() {
                        return mediaType;
                    }

                    @Override
                    public void writeTo(BufferedSink sink) throws IOException {
                        sink.write(notification.getPayload().getBytes(Constants.UTF_8));
                    }
                })
                .header("content-length", notification.getPayload().getBytes(Constants.UTF_8).length + "");

        if (topic != null) {
            rb.header("apns-topic", topic);
        }

        if (collapseId != null) {
            rb.header("apns-collapse-id", collapseId);
        }

        if (uuid != null) {
            rb.header("apns-id", uuid.toString());
        }

        if (expiration > -1) {
            rb.header("apns-expiration", String.valueOf(expiration));
        }

        if (priority != null) {
            rb.header("apns-priority", String.valueOf(priority.getCode()));
        }

        if (keyID != null && teamID != null && apnsAuthKey != null) {

            // Generate a new JWT token if it's null, or older than 55 minutes
            if (cachedJWTToken == null || System.currentTimeMillis() - lastJWTTokenTS > 55 * 60 * 1000) {
                try {
                    lastJWTTokenTS = System.currentTimeMillis();
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        cachedJWTToken = JWT.getToken(teamID, keyID, apnsAuthKey);
                    }
                } catch (InvalidKeySpecException | NoSuchAlgorithmException | SignatureException | InvalidKeyException e) {
                    return null;
                }
            }

            rb.header("authorization", "bearer " + cachedJWTToken);
        }

        return rb.build();
    }


    @Override
    public NotificationResponse push(Notification notification) {
        final Request request = buildRequest(notification);
        Response response = null;

        try {
            response = client.newCall(request).execute();
            return parseResponse(response);
        } catch (Throwable t) {
            return new NotificationResponse(null, -1, null, t);
        } finally {
            if (response != null) {
                response.body().close();
            }
        }
    }

    @Override
    public OkHttpClient getHttpClient() {
        return client;
    }

    protected NotificationResponse parseResponse(Response response) throws IOException {
        String contentBody = null;
        int statusCode = response.code();

        NotificationRequestError error = null;

        if (response.code() != 200) {
            error = NotificationRequestError.get(statusCode);
            contentBody = response.body() != null ? response.body().string() : null;
        }

        return new NotificationResponse(error, statusCode, contentBody, null);
    }
}
