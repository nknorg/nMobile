package org.nkn.mobile.app.push.apns.notification;

/**
 * A wrapper around possible responses from the push gateway.
 */
public class NotificationResponse {
    private final NotificationRequestError error;
    private final int httpStatusCode;
    private final String responseBody;
    private final Throwable cause;

    public NotificationResponse(NotificationRequestError error, int httpStatusCode, String responseBody, Throwable cause) {
        this.error = error;
        this.httpStatusCode = httpStatusCode;
        this.responseBody = responseBody;
        this.cause = cause;
    }

    /**
     * Returns the throwable from the underlying HttpClient.
     *
     * @return The throwable
     */
    public Throwable getCause() {
        return cause;
    }

    /**
     * Returns the error.
     *
     * @return The error (null if no error)
     */
    public NotificationRequestError getError() {
        return error;
    }

    /**
     * Returns the real HTTP status code.
     *
     * @return The HTTP status code
     */
    public int getHttpStatusCode() {
        return httpStatusCode;
    }

    /**
     * Returns the content body (null for a successful response).
     *
     * @return The content body (null for a successful response)
     */
    public String getResponseBody() {
        return responseBody;
    }

    @Override
    public String toString() {
        return "NotificationResponse{" +
                "error=" + error +
                ", httpStatusCode=" + httpStatusCode +
                ", responseBody='" + responseBody + '\'' +
                ", cause=" + cause +
                '}';
    }
}
