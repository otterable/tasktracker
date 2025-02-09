// lib/screens/registration_screen.dart, do not remove this line!
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/screens/dashboard_screen.dart'; // NEW: Import the dashboard screen

class RegistrationScreen extends StatefulWidget {
  final String phone;
  const RegistrationScreen({Key? key, required this.phone}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _usernameController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorMessage = "Bitte Benutzername eingeben.";
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await ApiService.registerUser(widget.phone, username);
    setState(() {
      _isLoading = false;
    });
    if (result != null && result["status"] == "ok") {
      // Registration successful. Navigate directly to the DashboardScreen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            currentUser: username, // Updated parameter name
            onLogout: () {
              // Define your logout logic here. For example, navigate back to the login screen.
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result?["message"] ?? "Registrierung fehlgeschlagen.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Molentracker"),
      ),
      body: Container(
        // Use the same background image as the login screen.
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/molen.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.9), // Updated: using Color.fromRGBO instead of withOpacity
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const Text(
                    "Registrierung",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "Benutzername",
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _register,
                          child: const Text("Registrieren"),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
