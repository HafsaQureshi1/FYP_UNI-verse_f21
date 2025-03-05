import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/auth_io.dart' as auth show clientViaServiceAccount;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle; // Import this for reading assets

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initializeFCM() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ User granted permission for notifications");
    }

    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print("📲 FCM Token: $token");
      await _saveUserToken(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveUserToken);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔴 Foreground Notification: ${message.notification?.title}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🟡 App opened from notification: ${message.data}");
    });
  }

  Future<void> _saveUserToken(String token) async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'fcmToken': token});
    }
  }

  Future<String?> getAccessToken() async {
    try {
      // Load service account credentials from assets
      final String serviceAccountJson =
          await rootBundle.loadString("assets/universe-123-firebase-adminsdk-dxv5x-586f17d46e.json");

      // Parse the JSON file
      final Map<String, dynamic> credentials = jsonDecode(serviceAccountJson);

      // Create an authentication client
      final accountCredentials =
          auth.ServiceAccountCredentials.fromJson(credentials);
      final client = await auth.clientViaServiceAccount( 
  accountCredentials, 
  ["https://www.googleapis.com/auth/firebase.messaging"]
);


      return client.credentials.accessToken.data;
    } catch (e) {
      print("❌ Error getting OAuth token: $e");
      return null;
    }
  }

  /// Function to send notification using FCM v1 API
  Future<void> sendNotificationToUser(String userId, String message) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      print("❌ No user found with ID: $userId");
      return;
    }

    final String? fcmToken = userDoc.data()?['fcmToken'];
    if (fcmToken == null || fcmToken.isEmpty) {
      print("❌ No FCM token found for user.");
      return;
    }

    final String? accessToken = await getAccessToken();
    if (accessToken == null) {
      print("❌ Failed to get OAuth token.");
      return;
    }

    final Map<String, dynamic> notificationPayload = {
      "message": {
        "token": fcmToken,
        "notification": {
          "title": "New Like on Your Post! ❤️",
          "body": message,
        },
        "data": {
          "type": "like",
          "postId": userId,
        }
      }
    };

    final response = await http.post(
      Uri.parse("https://fcm.googleapis.com/v1/projects/universe-123/messages:send"),
      headers: <String, String>{
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode(notificationPayload),
    );

    if (response.statusCode == 200) {
      print("✅ Notification sent successfully!");
    } else {
      print("❌ Failed to send notification: ${response.body}");
    }
  }
}
