// lib/screens/login_screen.dart, do not remove this line!

import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // ADD a phone number controller
  final _phoneController = TextEditingController();

  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log In"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
              ),
              obscureText: true,
            ),
            // NEW: A phone number field
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Phone Number (e.g. +1987654321)",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Login"),
              onPressed: _attemptLogin,
            ),
          ],
        ),
      ),
    );
  }

  void _attemptLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();

    if (username.isEmpty || password.isEmpty || phone.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields (including phone)");
      return;
    }

    bool success = await ApiService.login(username, password, phone);
    if (success) {
      widget.onLoginSuccess(username);
    } else {
      setState(() => _errorMessage = "Invalid credentials");
    }
  }
}
