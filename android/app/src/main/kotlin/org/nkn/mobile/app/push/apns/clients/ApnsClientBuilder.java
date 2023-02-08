package org.nkn.mobile.app.push.apns.clients;

import org.nkn.mobile.app.push.apns.ApnsClient;

import java.io.IOException;
import java.io.InputStream;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.util.concurrent.TimeUnit;

import okhttp3.ConnectionPool;
import okhttp3.OkHttpClient;

/**
 * A builder to build an APNS client.
 */
public class ApnsClientBuilder {
    private InputStream certificate;
    private boolean production;
    private String password;

    private boolean asynchronous = false;
    private String defaultTopic = null;

    private OkHttpClient.Builder builder;
    private ConnectionPool connectionPool;
    private String apnsAuthKey;
    private String teamID;
    private String keyID;

    /**
     * Creates a default OkHttp client builder that can be customized later and
     * then passed to one of the constructors taking a builder instance. The
     * constructors that don't take builders themselves use this method
     * internally to create their client builders. Note: The returned Builder
     * also has a default connection pool configured. You can replace that pool
     * by calling {@link OkHttpClient.Builder#connectionPool(okhttp3.ConnectionPool) }.
     *
     * @return a new OkHttp client builder, intialized with default settings.
     */
    public static OkHttpClient.Builder createDefaultOkHttpClientBuilder() {
        OkHttpClient.Builder builder = new OkHttpClient.Builder();
        builder.connectTimeout(10, TimeUnit.SECONDS).writeTimeout(10, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS);
        builder.connectionPool(new ConnectionPool(10, 10, TimeUnit.MINUTES));
        return builder;
    }

    /**
     * Replaces the default OkHttp client builder with this one. The default
     * builder is created internally with {@link #createDefaultOkHttpClientBuilder() }.
     * A custom builder can also be created by calling that method explicitly,
     * customizing the builder and then passing it to this method.
     *
     * @param clientBuilder An existing OkHttp client builder to be used as the base
     * @return this object
     */
    public ApnsClientBuilder withOkHttpClientBuilder(OkHttpClient.Builder clientBuilder) {
        this.builder = clientBuilder;
        return this;
    }

    public ApnsClientBuilder withConnectionPool(ConnectionPool connectionPool) {
        this.connectionPool = connectionPool;
        return this;
    }

    public ApnsClientBuilder withCertificate(InputStream inputStream) {
        certificate = inputStream;
        return this;
    }

    public ApnsClientBuilder withPassword(String password) {
        this.password = password;
        return this;
    }

    public ApnsClientBuilder withApnsAuthKey(String apnsAuthKey) {
        this.apnsAuthKey = apnsAuthKey;
        return this;
    }

    public ApnsClientBuilder withTeamID(String teamID) {
        this.teamID = teamID;
        return this;
    }

    public ApnsClientBuilder withKeyID(String keyID) {
        this.keyID = keyID;
        return this;
    }

    public ApnsClientBuilder withProductionGateway() {
        this.production = true;
        return this;
    }

    public ApnsClientBuilder withProductionGateway(boolean production) {
        if (production) return withProductionGateway();

        return withDevelopmentGateway();
    }

    public ApnsClientBuilder withDevelopmentGateway() {
        this.production = false;
        return this;
    }

    public ApnsClientBuilder inSynchronousMode() {
        asynchronous = false;
        return this;
    }

    public ApnsClientBuilder inAsynchronousMode() {
        asynchronous = true;
        return this;
    }

    public ApnsClientBuilder withDefaultTopic(String defaultTopic) {
        this.defaultTopic = defaultTopic;
        return this;
    }

    public ApnsClient build() throws CertificateException,
            NoSuchAlgorithmException, KeyStoreException, IOException,
            UnrecoverableKeyException, KeyManagementException {

        if (builder == null) {
            builder = createDefaultOkHttpClientBuilder();
        }

        if (connectionPool != null) {
            builder.connectionPool(connectionPool);
        }

        if (certificate != null) {
            if (asynchronous) {
                return new AsyncOkHttpApnsClient(certificate, password, production, defaultTopic, builder);
            } else {
                return new SyncOkHttpApnsClient(certificate, password, production, defaultTopic, builder);
            }
        } else if (keyID != null && teamID != null && apnsAuthKey != null) {
            if (asynchronous) {
                return new AsyncOkHttpApnsClient(apnsAuthKey, teamID, keyID, production, defaultTopic, builder);
            } else {
                return new SyncOkHttpApnsClient(apnsAuthKey, teamID, keyID, production, defaultTopic, builder);
            }
        } else {
            throw new IllegalArgumentException("Either the token credentials (team ID, key ID, and the private key) " +
                    "or a certificate must be provided");
        }
    }
}
