package org.nkn.mobile.app.push;

import android.content.SharedPreferences;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import org.jetbrains.annotations.NotNull;
import org.nkn.mobile.app.MainActivity;
import org.nkn.mobile.app.channels.impl.Common;

import java.util.HashMap;

public class FCMPushService extends FirebaseMessagingService {
    private static final String TAG = "FCMPushService";

    @Override
    public void onNewToken(@NonNull String refreshToken) {
        super.onNewToken(refreshToken);
        Log.i(TAG, "onNewToken: " + refreshToken);
        SharedPreferences.Editor editor = getSharedPreferences("fcmToken", MODE_PRIVATE).edit();
        editor.putString("token", refreshToken);
        editor.apply();
        // notify flutter
        Common.Companion.eventAdd("onDeviceTokenRefresh", refreshToken);
    }

    @Override
    public void onMessageReceived(@NotNull RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);
        Log.i(TAG, "onMessageReceived - Form:" + remoteMessage.getFrom() + " - payload: " + remoteMessage.getData());
        RemoteMessage.Notification notification = remoteMessage.getNotification();
        if (notification != null) {
            String title = notification.getTitle();
            String content = notification.getBody();
            Log.i(TAG, "onMessageReceived - title: " + title + " - content:" + content);
            // notify flutter
            HashMap<String, Object> resultMap = new HashMap<String, Object>();
            resultMap.put("isApplicationForeground", Common.Companion.isApplicationForeground(MainActivity.Companion.getInstance()));
            resultMap.put("title", title);
            resultMap.put("content", content);
            Common.Companion.eventAdd("onRemoteMessageReceived", resultMap);
        }

    }
}