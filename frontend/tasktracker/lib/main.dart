// lib/main.dart, do not remove this line!

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for SystemChrome if needed
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_tasktracker/screens/login_screen.dart';
import 'package:flutter_tasktracker/screens/dashboard_screen.dart';
import 'package:flutter_tasktracker/api_service.dart';

// For local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  // Android initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  // Ensure that you have an icon named ic_launcher in your mipmap folders

  // iOS initialization
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  // Other platforms if desired
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      // Handle notification tap or action here if desired
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize date formatting for the German locale
  await initializeDateFormatting('de_DE', null);

  // 2) Initialize local notifications
  await _initNotifications();

  // 3) Load persistent login state before running the app
  final prefs = await SharedPreferences.getInstance();
  final storedUser = prefs.getString('currentUser') ?? "";

  runApp(MyTaskTrackerApp(initialUser: storedUser));
}

class MyTaskTrackerApp extends StatefulWidget {
  final String initialUser;

  const MyTaskTrackerApp({Key? key, required this.initialUser}) : super(key: key);

  @override
  State<MyTaskTrackerApp> createState() => _MyTaskTrackerAppState();
}

class _MyTaskTrackerAppState extends State<MyTaskTrackerApp> {
  bool _isLoggedIn = false;
  String _currentUser = ""; // e.g., "weasel" or "Otter"
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    // Set login state based on the persistent storage
    if (widget.initialUser.isNotEmpty) {
      _isLoggedIn = true;
      _currentUser = widget.initialUser;
    }
    // Start heartbeat checks every 5 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final ok = await ApiService.getHeartbeat();
      if (!ok) {
        debugPrint("[Heartbeat] Server heartbeat check FAILED!");
      } else {
        debugPrint("[Heartbeat] Server is alive (heartbeat ok).");
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  // When login is successful, persist the username
  Future<void> _login(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUser', username);
    setState(() {
      _isLoggedIn = true;
      _currentUser = username;
    });
  }

  // On logout, remove the stored username
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');
    setState(() {
      _isLoggedIn = false;
      _currentUser = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build theme using your custom colors
    final theme = ThemeData(
      fontFamily: 'Roboto',
      primaryColor: const Color(0xFF003056),
      scaffoldBackgroundColor: const Color(0xFFF5F1E4),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF003056), // top bars
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: const Color(0xFF003056),
        secondary: const Color(0xFF02569D),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white, // button text color
          backgroundColor: const Color(0xFFFF5C00), // orange
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );

    return MaterialApp(
      title: 'Molentracker',
      theme: theme,
      home: _isLoggedIn
          ? DashboardScreen(
              currentUser: _currentUser,
              onLogout: _logout,
            )
          : LoginScreen(onLoginSuccess: _login),
    );
  }
}
