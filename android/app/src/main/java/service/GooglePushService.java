package service;


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
import java.util.Collections;
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

    private String v0TokenString = "XXXXXX";

    public String getAuth(InputStream sStream) throws IOException {
//        private static String getAccessToken() {
//            GoogleCredential googleCredential = GoogleCredential
//                    .fromStream(new FileInputStream("service-account.json"))
//                    .createScoped(Array.as(SCOPES));
//            googleCredential.refreshToken();
//            return googleCredential.getAccessToken();
//        }
//        String pathExternalPublic = Environment.getDataDirectory().getAbsolutePath();
//        Log.e("XXXXXX",pathExternalPublic);
//
        GoogleCredential googleCredential = GoogleCredential
                .fromStream(sStream)
                .createScoped(Collections.singleton(SCOPES));
        googleCredential.refreshToken();
        String tokenValue = googleCredential.getAccessToken();
//        AccessToken token = googleCredential.getAccessToken();
//        if (token != null){
//            return token.getTokenValue();
//        }
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

    public void sendMessage() throws IOException, JSONException {
        String deviceToken = "XXXXXXXX";
        JSONObject sendingData = sendJsonData(deviceToken);

        Log.e("Sending DDDDD",sendingData.toString());
        HttpURLConnection connection = this.getConnection();
        connection.setDoOutput(true);
        DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());
        outputStream.writeBytes(sendingData.toString());
        outputStream.flush();
        outputStream.close();

        int responseCode = connection.getResponseCode();
        Log.e("responseCode+", Integer.toString(responseCode));


        if (responseCode == 200) {
            Log.e("SSSSSSSSS","Message sent to Firebase for delivery, response:");
            System.out.println(connection.getResponseMessage());
        } else {
            String response = inputstreamToString(connection.getErrorStream());
            Log.e("EEEEEEE+",response);
            Log.e("EEEEEEEEEE","Unable to send message to Firebase:");
            Log.e("EEEEEEE+",response);
        }
    }

    public void sendV0Message() throws IOException, JSONException{
        String deviceToken = "XXXXXXXXX";
        JSONObject sendingData = sendJsonDataV0(deviceToken);

        Log.e("Sending VOOOOOOO",sendingData.toString());
        HttpURLConnection connection = this.getV0Connection();
        connection.setDoOutput(true);
        DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());
        outputStream.writeBytes(sendingData.toString());
        outputStream.flush();
        outputStream.close();

        int responseCode = connection.getResponseCode();
        Log.e("responseCode+", Integer.toString(responseCode));


        if (responseCode == 200) {
            Log.e("SSSSSSSSS","Message sent to Firebase for delivery, response:");
            System.out.println(connection.getResponseMessage());
        } else {
            String response = inputstreamToString(connection.getErrorStream());
            Log.e("EEEEEEE+",response);
            Log.e("EEEEEEEEEE","Unable to send message to Firebase:");
            Log.e("EEEEEEE+",response);
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

    private static JSONObject sendJsonDataV0(String deviceToken) throws JSONException {

        JSONObject data = new JSONObject();
        data.put("to", deviceToken);
        JSONObject info = new JSONObject();
        info.put("title", "FCM V0 Title"); // Notification title
        info.put("body", "Breaking News!!!!!!!"); // Notification body
        data.put("notification", info);

//        JSONObject messageInfo = new JSONObject();
//        messageInfo.put("message",data);

//        JSONObject root = new JSONObject();
//        JSONObject notification = new JSONObject();
//
//        notification.put("body", BODY);
//        notification.put("title",TITLE);
//
//        JSONObject data = new JSONObject();
//        data.put("message", MESSAGE_KEY);
//        root.put("notification", notification);
//        root.put("data", data);
//
//        root.put("registration_ids", deviceToken);
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

//        JSONObject root = new JSONObject();
//        JSONObject notification = new JSONObject();
//
//        notification.put("body", BODY);
//        notification.put("title",TITLE);
//
//        JSONObject data = new JSONObject();
//        data.put("message", MESSAGE_KEY);
//        root.put("notification", notification);
//        root.put("data", data);
//
//        root.put("registration_ids", deviceToken);
        return messageInfo;
    }
}