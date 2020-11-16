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
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.installations.FirebaseInstallations;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import org.nkn.mobile.app.MainActivity;
import org.nkn.mobile.app.R;

import java.util.ArrayList;
import java.util.Map;

public class MyFirebaseMessagingService extends FirebaseMessagingService {

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);
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
            sendNotification(title,messageContent);

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

    private void judgeNotificationOpen() {
        NotificationManagerCompat manager = NotificationManagerCompat.from(this);
        // areNotificationsEnabled方法的有效性官方只最低支持到API 19，低于19的仍可调用此方法不过只会返回true，即默认为用户已经开启了通知。
        boolean isOpened = manager.areNotificationsEnabled();

        if (isOpened == false){
            try {
                // 根据isOpened结果，判断是否需要提醒用户跳转AppInfo页面，去打开App通知权限
                Intent intent = new Intent();
                intent.setAction(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
//                //这种方案适用于 API 26, 即8.0（含8.0）以上可以用
//                intent.putExtra(Intent.EXTRA_PACKAGE_NAME, getPackageName());
//                intent.putExtra(Intent, getApplicationInfo().uid);

                //这种方案适用于 API21——25，即 5.0——7.1 之间的版本可以使用
                intent.putExtra("app_package", getPackageName());
                intent.putExtra("app_uid", getApplicationInfo().uid);

                // 小米6 -MIUI9.6-8.0.0系统，是个特例，通知设置界面只能控制"允许使用通知圆点"——然而这个玩意并没有卵用，我想对雷布斯说：I'm not ok!!!
                //  if ("MI 6".equals(Build.MODEL)) {
                //      intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                //      Uri uri = Uri.fromParts("package", getPackageName(), null);
                //      intent.setData(uri);
                //      // intent.setAction("com.android.settings/.SubSettings");
                //  }
                startActivity(intent);
            } catch (Exception e) {
                e.printStackTrace();
                // 出现异常则跳转到应用设置界面：锤子坚果3——OC105 API25
                Intent intent = new Intent();

                //下面这种方案是直接跳转到当前应用的设置界面。
                //https://blog.csdn.net/ysy950803/article/details/71910806
                intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                Uri uri = Uri.fromParts("package", getPackageName(), null);
                intent.setData(uri);
                startActivity(intent);
            }
        }
    }
}