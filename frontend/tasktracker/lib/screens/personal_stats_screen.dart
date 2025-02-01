// lib/screens/personal_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';

class PersonalStatsScreen extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const PersonalStatsScreen({Key? key, required this.username, required this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder data
    final totalDone = 12;
    final avgTime = "10h";
    final favoriteTask = "Küche";
    final favoriteCount = 8;
    final leastFavTask = "kochen";
    final leastFavCount = 2;

    return Scaffold(
      appBar: AppBar(
        title: Text("Statistiken für $username"),
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 2,
        currentUser: username,
        onLogout: onLogout,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Benutzer: $username",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Insgesamt erledigt: $totalDone"),
                Text("Durchschnittliche Zeit pro Aufgabe: $avgTime"),
                Text("Lieblingsaufgabe: $favoriteTask ($favoriteCount mal)"),
                Text("Unbeliebteste Aufgabe: $leastFavTask ($leastFavCount mal)"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
