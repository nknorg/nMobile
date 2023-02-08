package org.nkn.mobile.app.push.apns.notification;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.nkn.mobile.app.push.apns.clients.AsyncOkHttpApnsClient;

import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.UUID;

/**
 * An entity containing the payload and the token.
 */
public class Notification {
    private final String payload;
    private final String token;
    private final String topic;
    private final String collapseId;
    private final long expiration;
    private final Notification.Priority priority;
    private final UUID uuid;

    public enum Priority {
        IMMEDIATE(10),
        POWERCONSIDERATION(5);

        private final int code;

        private Priority(int code) {
            this.code = code;
        }

        public int getCode() {
            return this.code;
        }
    }


    /**
     * Constructs a new Notification with a payload and token.
     *
     * @param payload    The JSON body (which is used for the request)
     * @param token      The device token
     * @param topic      The topic for this notification
     * @param collapseId The collapse ID
     * @param expiration A UNIX epoch date expressed in seconds (UTC)
     * @param priority   The priority of the notification (10 or 5)
     * @param uuid       A canonical UUID that identifies the notification
     */
    protected Notification(String payload, String token, String topic, String collapseId, long expiration, Notification.Priority priority, UUID uuid) {
        this.payload = payload;
        this.token = token;
        this.topic = topic;
        this.collapseId = collapseId;
        this.expiration = expiration;
        this.priority = priority;
        this.uuid = uuid;
    }

    /**
     * Retrieves the topic.
     *
     * @return The topic
     */
    public String getTopic() {
        return topic;
    }

    /**
     * Retrieves the collapseId.
     *
     * @return The collapseId
     */
    public String getCollapseId() {
        return collapseId;
    }

    /**
     * Retrieves the payload.
     *
     * @return The payload
     */
    public String getPayload() {
        return payload;
    }

    /**
     * Retrieves the token.
     *
     * @return The device token
     */
    public String getToken() {
        return token;
    }

    public long getExpiration() {
        return expiration;
    }

    public Notification.Priority getPriority() {
        return priority;
    }

    public UUID getUuid() {
        return uuid;
    }

    /**
     * Builds a notification to be sent to APNS.
     */
    public static class Builder {
        private final ObjectMapper mapper = new ObjectMapper();

        private final HashMap<String, Object> root, aps, alert;
        private final String token;
        private String topic = null;
        private String collapseId = null;
        private long expiration = -1; // defaults to -1, as 0 is a valid value (included only if greater than -1)
        private Notification.Priority priority;
        private UUID uuid;

        /**
         * Creates a new notification builder.
         *
         * @param token The device token
         */
        public Builder(String token) {
            this.token = token;
            root = new HashMap<>();
            aps = new HashMap<>();
            alert = new HashMap<>();
        }

        public Notification.Builder mutableContent(boolean mutable) {
            if (mutable) {
                aps.put("mutable-content", 1);
            } else {
                aps.remove("mutable-content");
            }

            return this;
        }

        public Notification.Builder mutableContent() {
            return this.mutableContent(true);
        }

        public Notification.Builder contentAvailable(boolean contentAvailable) {
            if (contentAvailable) {
                aps.put("content-available", 1);
            } else {
                aps.remove("content-available");
            }

            return this;
        }

        public Notification.Builder contentAvailable() {
            return this.contentAvailable(true);
        }

        public Notification.Builder alertBody(String body) {
            alert.put("body", body);
            return this;
        }

        public Notification.Builder alertTitle(String title) {
            alert.put("title", title);
            return this;
        }

        public Notification.Builder sound(String sound) {
            if (sound != null) {
                aps.put("sound", sound);
            } else {
                aps.remove("sound");
            }

            return this;
        }

        public Notification.Builder category(String category) {
            if (category != null) {
                aps.put("category", category);
            } else {
                aps.remove("category");
            }
            return this;
        }

        public Notification.Builder badge(int badge) {
            aps.put("badge", badge);
            return this;
        }

        public Notification.Builder customField(String key, Object value) {
            root.put(key, value);
            return this;
        }

        public Notification.Builder topic(String topic) {
            this.topic = topic;
            return this;
        }

        public Notification.Builder collapseId(String collapseId) {
            this.collapseId = collapseId;
            return this;
        }

        public Notification.Builder expiration(long expiration) {
            this.expiration = expiration;
            return this;
        }

        public Notification.Builder uuid(UUID uuid) {
            this.uuid = uuid;
            return this;
        }

        public Notification.Builder priority(Notification.Priority priority) {
            this.priority = priority;
            return this;
        }

        public int size() {
            try {
                return build().getPayload().getBytes("UTF-8").length;
            } catch (UnsupportedEncodingException e) {
                throw new RuntimeException(e);
            }
        }

        /**
         * Builds the notification.
         * Also see {@link AsyncOkHttpApnsClient#push(Notification, NotificationResponseListener)}
         *
         * @return The notification
         */
        public Notification build() {
            root.put("aps", aps);
            aps.put("alert", alert);

            final String payload;
            try {
                payload = mapper.writeValueAsString(root);
            } catch (JsonProcessingException e) {
                // Should not happen
                throw new RuntimeException(e);
            }
            return new Notification(payload, token, topic, collapseId, expiration, priority, uuid);
        }
    }
}
