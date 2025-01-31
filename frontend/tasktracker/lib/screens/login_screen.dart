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
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpRequested = false;
  String? _errorMessage;

  Future<void> _requestOtp() async {
    setState(() {
      _errorMessage = null;
    });
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Bitte Telefonnummer eingeben.");
      return;
    }
    final success = await ApiService.requestOtp(phone);
    if (success) {
      setState(() {
        _otpRequested = true;
      });
    } else {
      setState(() => _errorMessage = "Fehler beim Anfordern des Codes. Prüfe Telefonnummer oder Server.");
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _errorMessage = null;
    });
    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = "Bitte sowohl Telefonnummer als auch Code eingeben.");
      return;
    }
    final username = await ApiService.verifyOtp(phone, code);
    if (username != null) {
      widget.onLoginSuccess(username);
    } else {
      setState(() => _errorMessage = "Code oder Telefonnummer ungültig.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep your app bar if you wish
      appBar: AppBar(
        title: const Text("Molentracker"),
      ),
      body: Container(
        // 1) Full background image
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/molen.png"),
            fit: BoxFit.cover, // fill the screen while cropping
          ),
        ),
        child: Center(
          // 2) A scrollable center layout for smaller screens
          child: SingleChildScrollView(
            // 3) A white “card” with padding
            child: Container(
              width: 300, // you can adjust to your taste
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
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

                  // 4) German labels, bold & black
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Handynummer",
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_otpRequested) ...[
                    ElevatedButton(
                      onPressed: _requestOtp,
                      child: const Text("OTP anfordern"),
                    ),
                  ] else ...[
                    TextField(
                      controller: _otpController,
                      decoration: const InputDecoration(
                        labelText: "Bestätigungs-Code",
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _verifyOtp,
                      child: const Text("Code prüfen"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
