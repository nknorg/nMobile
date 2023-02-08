package org.nkn.mobile.app.push.apns.notification;

/**
 * An interface for handling responses to notification requests.
 */
public interface NotificationResponseListener {
    /**
     * Signals a successful notification.
     * <p>
     * Note: For a successful request, the response body is empty.
     *
     * @param notification The notification that succeeded
     */
    void onSuccess(Notification notification);

    /**
     * Signals a failed notification.
     *
     * @param notification The notification that failed
     * @param response     The notification response
     */
    void onFailure(Notification notification, NotificationResponse response);
}
