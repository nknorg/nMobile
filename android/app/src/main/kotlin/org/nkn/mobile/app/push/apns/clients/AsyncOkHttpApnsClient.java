package org.nkn.mobile.app.push.apns.clients;

import org.nkn.mobile.app.push.apns.notification.Notification;
import org.nkn.mobile.app.push.apns.notification.NotificationResponse;
import org.nkn.mobile.app.push.apns.notification.NotificationResponseListener;

import java.io.IOException;
import java.io.InputStream;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.ConnectionPool;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * A wrapper around OkHttp's http client to send out notifications using Apple's HTTP/2 API.
 */
public class AsyncOkHttpApnsClient extends SyncOkHttpApnsClient {

    public AsyncOkHttpApnsClient(String apnsAuthKey, String teamID, String keyID,
                                 boolean production, String defaultTopic, ConnectionPool connectionPool) {
        super(apnsAuthKey, teamID, keyID, production, defaultTopic, connectionPool);
    }

    public AsyncOkHttpApnsClient(InputStream certificate, String password, boolean production,
                                 String defaultTopic, ConnectionPool connectionPool)
            throws CertificateException, NoSuchAlgorithmException, KeyStoreException,
            IOException, UnrecoverableKeyException, KeyManagementException {
        super(certificate, password, production, defaultTopic, connectionPool);
    }

    public AsyncOkHttpApnsClient(String apnsAuthKey, String teamID, String keyID,
                                 boolean production, String defaultTopic, OkHttpClient.Builder builder) {
        super(apnsAuthKey, teamID, keyID, production, defaultTopic, builder);
    }

    public AsyncOkHttpApnsClient(InputStream certificate, String password, boolean production,
                                 String defaultTopic, OkHttpClient.Builder builder)
            throws CertificateException, NoSuchAlgorithmException, KeyStoreException,
            IOException, UnrecoverableKeyException, KeyManagementException {
        super(certificate, password, production, defaultTopic, builder);
    }

    @Override
    public NotificationResponse push(Notification notification) {
        throw new UnsupportedOperationException("Synchronous requests are not supported by this client");
    }

    @Override
    public boolean isSynchronous() {
        return false;
    }

    @Override
    public void push(Notification notification, NotificationResponseListener nrl) {
        final Request request = buildRequest(notification);

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                nrl.onFailure(notification, new NotificationResponse(null, -1, null, e));
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                final NotificationResponse nr;

                try {
                    nr = parseResponse(response);
                } catch (Throwable t) {
                    nrl.onFailure(notification, new NotificationResponse(null, -1, null, t));
                    return;
                } finally {
                    if (response != null) {
                        response.body().close();
                    }
                }

                if (nr.getHttpStatusCode() == 200) {
                    nrl.onSuccess(notification);
                } else {
                    nrl.onFailure(notification, nr);
                }
            }
        });

    }
}
