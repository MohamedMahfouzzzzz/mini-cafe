// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // We'll pass the navigator key from main.dart
  late GlobalKey<NavigatorState> navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  Future<void> init() async {
    // Request permission for iOS
    await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Get the token and save it to Firestore
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'deviceToken': token});
      }
    }

    // This is the magic: listen for messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');
    if (message.notification != null) {
      debugPrint(
        'Message also contained a notification: ${message.notification!.title}',
      );

      // Show a SnackBar using the navigator key
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.body ?? 'New Order Update!'),
            backgroundColor: const Color(0xFF6F4E37),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
