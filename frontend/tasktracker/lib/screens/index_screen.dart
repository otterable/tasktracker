// lib/screens/index_screen.dart, do not remove this line!

import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/screens/dashboard_screen.dart';

class IndexScreen extends StatefulWidget {
  const IndexScreen({Key? key}) : super(key: key);

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    debugPrint("[IndexScreen] build called");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Household Task Tracker (Flutter)"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null)
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red)),

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text("Login"),
              onPressed: _handleLogin,
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    debugPrint("[IndexScreen] Login button pressed.");
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    debugPrint("[IndexScreen] username=$username, password=$password");

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please enter username and password";
      });
      debugPrint("[IndexScreen] Missing username/password!");
      return;
    }

    bool success = await ApiService.login(username, password);
    debugPrint("[IndexScreen] ApiService.login returned => $success");
    if (success) {
      debugPrint("[IndexScreen] Login success! Navigating to Dashboard...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            currentUser: username,
            onLogout: () {
              // Return to this screen if user logs out
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const IndexScreen()),
              );
            },
          ),
        ),
      );
    } else {
      debugPrint("[IndexScreen] Login failure. Setting error message.");
      setState(() {
        _errorMessage = "Invalid credentials";
      });
    }
  }
}
