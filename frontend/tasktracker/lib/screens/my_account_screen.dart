// lib/screens/my_account_screen.dart
import 'package:flutter/material.dart';

class MyAccountScreen extends StatelessWidget {
  final String currentUser;
  final VoidCallback onLogout;

  const MyAccountScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mein Konto"),
      ),
      body: Center(
        child: Text(
          "Account details for $currentUser",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
