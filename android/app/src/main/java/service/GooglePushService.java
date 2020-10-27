package service;


//import android.os.Environment;
//import android.os.Message;
//import android.util.Log;
//
//import com.google.auth.oauth2.AccessToken;
//import com.google.auth.oauth2.GoogleCredentials;
//import com.google.firebase.FirebaseException;
//import com.google.firebase.messaging.FirebaseMessaging;
//import com.google.firebase.messaging.RemoteMessage;
//
//import java.io.FileInputStream;
//import java.io.IOException;
//import java.io.InputStream;
//import java.util.Collections;

public class GooglePushService {
    private static final String SCOPES = "";

//    public String getAuth(InputStream sStream) throws IOException {
//        String pathExternalPublic = Environment.getDataDirectory().getAbsolutePath();
//        Log.e("XXXXXX",pathExternalPublic);
//
//
//        GoogleCredentials googleCredential = GoogleCredentials
//                .fromStream(sStream)
//                .createScoped(Collections.singleton("https://www.googleapis.com/auth/cloud-platform"));
//        googleCredential.refreshAccessToken();
//        AccessToken accessToken = googleCredential.getAccessToken();
//        return accessToken.getTokenValue();
//    }

//    public void sendMessage() throws FirebaseException {
//        String topic = "highScores";
//
//        String postUrl = "https://fcm.googleapis.com/v1/projects/nmobile-df2f8/messages:send";
//        RemoteMessage remoteMessage
//        FirebaseMessaging.getInstance().send();
//        Firebase
//
//// See documentation on defining a message payload.
//        Message
//        RemoteMessage message = Message.bui()
//                .putData("score", "850")
//                .putData("time", "2:45")
//                .setTopic(topic)
//                .build();
//
//// Send a message to the devices subscribed to the provided topic.
//        String response = FirebaseMessaging.getInstance().send(message);
// Response is a message ID string.
//        System.out.println("Successfully sent message: " + response);
//    }
}
