package service;


import android.provider.Settings;
import android.util.Log;

import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.DataOutputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Array;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Scanner;


public class GooglePushService {
    private static final String SCOPES = "https://www.googleapis.com/auth/firebase.messaging";

    private static final String BASE_URL = "https://fcm.googleapis.com";
    private static final String FCM_SEND_ENDPOINT = "/v1/projects/" + "nmobile" + "/messages:send";

    private static final String TITLE = "FCM Notification";
    private static final String BODY = "Notification from FCM";
    public static final String MESSAGE_KEY = "dsalkjdas";

    private String tokenString = "AIzaSyBLPB-l2_w7LgeeyaLMQBiX3jVfTHf1ez0";

    private static final String FCM_SEND_V0 = "https://fcm.googleapis.com/fcm/send";

    private String v0TokenString = "Add your own FCM token Here";

    public String getAuth(InputStream sStream) throws IOException {
        GoogleCredential googleCredential = GoogleCredential
                .fromStream(sStream)
                .createScoped(Collections.singleton(SCOPES));
        googleCredential.refreshToken();
        String tokenValue = googleCredential.getAccessToken();
        if (tokenValue == null){
            return "no token!!!!";
        }
        return tokenValue;
    }

    public void setAccessToken(String accessToken){
        tokenString = accessToken;
    }

    private HttpURLConnection getConnection() throws IOException {
        // [START use_access_token]
        URL url = new URL(BASE_URL + FCM_SEND_ENDPOINT);
        HttpURLConnection httpURLConnection = (HttpURLConnection) url.openConnection();
        httpURLConnection.setRequestProperty("Authorization", "Bearer " + this.tokenString);
        httpURLConnection.setRequestProperty("Content-Type", "application/json; UTF-8");
        return httpURLConnection;
        // [END use_access_token]
    }

    private HttpURLConnection getV0Connection() throws IOException {
        // [START use_access_token]
        URL url = new URL(FCM_SEND_V0);
        HttpURLConnection httpURLConnection = (HttpURLConnection) url.openConnection();
        httpURLConnection.setRequestProperty("Authorization", "key="+v0TokenString);
        httpURLConnection.setRequestMethod("POST");
        httpURLConnection.setRequestProperty("Content-Type", "application/json");
        return httpURLConnection;
        // [END use_access_token]
    }

    public void sendMessageToFireBase(String deviceToken,String content) throws JSONException, IOException {
        Log.e("DeviceToken+", deviceToken);

        String fcmToken = deviceToken;
        String fcmGapString = "__FCMToken__:";
        String[] sList = deviceToken.split(fcmGapString);
        if (sList.length > 1){
            fcmToken = sList[1].toString();
        }

        JSONObject sendingData = sendJsonDataV0(fcmToken,content);

        HttpURLConnection connection = this.getV0Connection();
        connection.setDoOutput(true);
        DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());
        outputStream.writeBytes(sendingData.toString());
        outputStream.flush();
        outputStream.close();

        int responseCode = connection.getResponseCode();
        Log.e("responseCode+", Integer.toString(responseCode));

        if (responseCode == 200) {
            System.out.println(connection.getResponseMessage());
        } else {
            String response = inputstreamToString(connection.getErrorStream());
            Log.e("SendMessage to Firebase Error:",response);
        }
    }

    public void sendMessage() throws IOException, JSONException {
        String deviceToken = "eBY4pc6NRZSCTpv0Wx4eUZ:APA91bGpxmuUwn89JEuyUF5YuF-jRcA4JOG2DDLx3g8HSs8kJo0FLtdWP6nS6N_xsyAWrGmNFuHUklbPJt4HHpTn5b7jto8433qXcGXr_mDnXlNa1qqB3zHgs2DUHmluSGvMGfjsJ5CY";
        JSONObject sendingData = sendJsonData(deviceToken);

        HttpURLConnection connection = this.getConnection();
        connection.setDoOutput(true);
        DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());
        outputStream.writeBytes(sendingData.toString());
        outputStream.flush();
        outputStream.close();

        int responseCode = connection.getResponseCode();
        if (responseCode == 200) {
            System.out.println(connection.getResponseMessage());
        } else {
            String response = inputstreamToString(connection.getErrorStream());
            Log.e("sendMessage Error:",response);
        }
    }

    public void sendV0Message() throws IOException, JSONException{
        String deviceToken = "eBY4pc6NRZSCTpv0Wx4eUZ:APA91bGpxmuUwn89JEuyUF5YuF-jRcA4JOG2DDLx3g8HSs8kJo0FLtdWP6nS6N_xsyAWrGmNFuHUklbPJt4HHpTn5b7jto8433qXcGXr_mDnXlNa1qqB3zHgs2DUHmluSGvMGfjsJ5CY";
        JSONObject sendingData = sendJsonDataV0(deviceToken,"VOContent");

        Log.e("Sending VOOOOOOO",sendingData.toString());
        HttpURLConnection connection = this.getV0Connection();
        connection.setDoOutput(true);
        DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());
        outputStream.writeBytes(sendingData.toString());
        outputStream.flush();
        outputStream.close();

        int responseCode = connection.getResponseCode();

        if (responseCode == 200) {
            System.out.println(connection.getResponseMessage());
        } else {
            String response = inputstreamToString(connection.getErrorStream());
            Log.e("sendV0Message Error:",response);
        }
    }

    private static String inputstreamToString(InputStream inputStream) throws IOException {
        StringBuilder stringBuilder = new StringBuilder();
        Scanner scanner = new Scanner(inputStream);
        while (scanner.hasNext()) {
            stringBuilder.append(scanner.nextLine());
        }
        return stringBuilder.toString();
    }

    private static JSONObject sendJsonDataV0(String deviceToken,String content) throws JSONException {
        JSONObject data = new JSONObject();
        data.put("to", deviceToken);
        JSONObject info = new JSONObject();
        info.put("title", "New Message!"); // Notification title
        info.put("body", content); // Notification body
        data.put("notification", info);

        return data;
    }

    private static JSONObject sendJsonData(String deviceToken) throws JSONException {
        JSONObject data = new JSONObject();
        data.put("token", deviceToken);
        JSONObject info = new JSONObject();
        info.put("title", "FCM Notificatoin Title"); // Notification title
        info.put("body", "Hello First Test notification"); // Notification body
        data.put("notification", info);

        JSONObject messageInfo = new JSONObject();
        messageInfo.put("message",data);

        return messageInfo;
    }
}