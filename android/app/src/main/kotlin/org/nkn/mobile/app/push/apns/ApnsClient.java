package org.nkn.mobile.app.push.apns;

import org.nkn.mobile.app.push.apns.notification.Notification;
import org.nkn.mobile.app.push.apns.notification.NotificationResponse;
import org.nkn.mobile.app.push.apns.notification.NotificationResponseListener;

import okhttp3.OkHttpClient;

/**
 * Interface for general purpose APNS clients.
 */
public interface ApnsClient {

    /**
     * Checks whether the client supports synchronous operations.
     * <p>
     * This is specified when building the client using
     *
     * @return Whether the client supports synchronous operations
     */
    boolean isSynchronous();

    /**
     * Sends a notification asynchronously to the Apple Push Notification Service.
     *
     * @param notification The notification built using
     *                     {@link Notification.Builder}
     * @param listener     The listener to be called after the request is complete
     */
    void push(Notification notification, NotificationResponseListener listener);

    /**
     * Sends a notification synchronously to the Apple Push Notification Service.
     *
     * @param notification The notification built using
     *                     {@link Notification.Builder}
     * @return The notification response
     */
    NotificationResponse push(Notification notification);

    /**
     * Returns the underlying OkHttpClient instance.
     * This can be used for further customizations such as using proxies.
     *
     * @return The underlying OkHttpClient instance
     */
    OkHttpClient getHttpClient();
}
