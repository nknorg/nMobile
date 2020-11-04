package service;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.BitmapFactory;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import org.nkn.mobile.app.MainActivity;
import org.nkn.mobile.app.R;

import java.util.ArrayList;
import java.util.Map;

public class MyFirebaseMessagingService extends FirebaseMessagingService {

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        ArrayList<String> notificationString = new ArrayList<>();

        Log.e(TAG, "From: " + remoteMessage.getFrom());
        Log.e(TAG, "Message data payload: " + remoteMessage.getData());
        // Check if message contains a data payload.
        if (remoteMessage.getData().size() > 0) {
            Log.e(TAG, "Message data payload: " + remoteMessage.getData());

            Map<String, String> dataFromCloud = remoteMessage.getData();
            String action = dataFromCloud.get("action");
        }
        // Check if message contains a notification payload.
        if (remoteMessage.getNotification() != null) {
            String title = remoteMessage.getNotification().getTitle();
            String messageContent = remoteMessage.getNotification().getBody();
            Log.e(TAG, "收到通知 Message Notification Body: " + title);
            Log.e(TAG, "收到通知 Message Notification Body: " + messageContent);
//            sendNotification(title,messageContent);

//            GooglePushService service = new GooglePushService();
//            try {
//                service.sendMessage();
//            } catch (IOException e) {
//                e.printStackTrace();
//            } catch (JSONException e) {
//                e.printStackTrace();
//            }
        }
    }

    private final String TAG = "NotifyService";
    public final static String GATEWAY_LOG_PREFS = "GATEWAY_LOG_PREFS";  // 保存网关日志的XML文件名
    public final static String OTHER_LOG = "OTHER_LOG";  // 其他需要在消息中心显示的日志
    private int requestCode = 0;

    @Override
    public void onNewToken(@NonNull String refreshToken) {
        super.onNewToken(refreshToken);
        Log.e(TAG, "refreshed token: " + "__"+refreshToken+"__");
        // 1. 持久化生成的token，
        // 2. 发送事件通知RN层，分为两种情况：
        //      用户未登录，RN层不做处理（待用户登录后读取本地存储的token，并上报）
        //      用户已登录，RN层获取当前用户id、token及当前语言上报服务端
        SharedPreferences.Editor editor = getSharedPreferences("fcmToken", MODE_PRIVATE).edit();
        editor.putString("token", refreshToken);
        editor.apply();
        sendRefreshTokenBroadcast(refreshToken);
    }

    /**
     * 获取当前已登录用户的id
     * @return 用户id，如果未登录则为空
     */
    private String getCurrentUserId() {
        SharedPreferences prefs = getSharedPreferences("userMsg", MODE_PRIVATE);
        return prefs.getString("userId", "");
    }

    /**
     * 发送通知
     * @param contentTitle 通知标题
     * @param contentText 通知内容
     */
    private void sendNotification(String contentTitle, String contentText) {
        requestCode++;
        String channel_id = "TestChannel";
        String channel_name = "TestChannelName";
        Uri defaultNotifySound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);

        Intent intent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, requestCode, intent, PendingIntent.FLAG_ONE_SHOT);
        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(this, channel_id);
        notificationBuilder.setContentTitle(contentTitle)
                .setContentText(contentText)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setLargeIcon(BitmapFactory.decodeResource(getResources(), R.mipmap.ic_launcher))
                .setAutoCancel(true)
                .setSound(defaultNotifySound)
                .setContentIntent(pendingIntent);
        NotificationManager notificationManager = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);

        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.O) {
            NotificationChannel notificationChannel = new NotificationChannel(channel_id, channel_name, NotificationManager.IMPORTANCE_DEFAULT);
            notificationManager.createNotificationChannel(notificationChannel);
        }

        notificationManager.notify(requestCode, notificationBuilder.build());
    }

    /**
     * 发送广播通知NotificationModule更新token，并发送给RN层
     * @param refreshToken 更新的token
     */
    private void sendRefreshTokenBroadcast(String refreshToken) {
//        LocalBroadcastManager localBroadcastManager = LocalBroadcastManager.getInstance(this);
//        Intent intent = new Intent(getString(@"ddd"));
//        intent.putExtra("refreshToken", refreshToken);
//        localBroadcastManager.sendBroadcast(intent);
    }


}