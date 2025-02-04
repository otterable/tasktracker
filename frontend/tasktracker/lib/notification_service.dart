import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed to load assets.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // For the small icon, we must use a drawable resource.
    // We continue using 'ic_launcher' (as defined in your Android manifest and resources).
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('ic_launcher');
    const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    // Load the logo asset from assets/logo.png as ByteData.
    final ByteData bytes = await rootBundle.load('assets/logo.png');
    final Uint8List largeIcon = bytes.buffer.asUint8List();

    // Build Android notification details with the logo as the large icon.
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_notifications', // Channel ID
      'Tasks Channel',      // Channel name
      channelDescription: 'Notifications for task updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      largeIcon: ByteArrayAndroidBitmap(largeIcon),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformDetails,
    );
  }
}
