package org.nkn.mobile.app.push.apns.notification;

import java.util.HashMap;
import java.util.Map;

/**
 * A collection of all the HTTP status codes returned by Apple.
 */
public enum NotificationRequestError {
    BadRequest(400), BadMethod(405), DeviceTokenInactiveForTopic(410),
    PayloadTooLarge(413), TooManyRequestsForToken(429), InternalServerError(500),
    ServerUnavailable(503), InvalidProviderToken(403);
    public final int errorCode;

    NotificationRequestError(int errorCode) {
        this.errorCode = errorCode;
    }

    private static Map<Integer, NotificationRequestError> errorMap = new HashMap<>();

    static {
        for (NotificationRequestError notificationRequestError : NotificationRequestError.values()) {
            errorMap.put(notificationRequestError.errorCode, notificationRequestError);
        }
    }

    public static NotificationRequestError get(int errorCode) {
        return errorMap.get(errorCode);
    }
}
