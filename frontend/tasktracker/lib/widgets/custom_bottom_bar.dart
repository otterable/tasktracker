// lib/widgets/custom_bottom_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/screens/dashboard_screen.dart';
import 'package:flutter_tasktracker/screens/stats_screen.dart';
import 'package:flutter_tasktracker/screens/personal_stats_screen.dart';
import 'package:flutter_tasktracker/screens/my_account_screen.dart';

class CustomBottomBar extends StatelessWidget {
  final int selectedIndex; // currently unused; you may remove if not needed
  final String currentUser;
  final VoidCallback onLogout;

  const CustomBottomBar({
    Key? key,
    required this.selectedIndex,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  /// The Tasks button shows a popup menu to select one of the task-related screens.
  Widget _buildTasksButton(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: "Tasks",
      padding: EdgeInsets.zero, // set padding to zero to avoid overflow
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.task, size: 20, color: Colors.black87),
          SizedBox(height: 2),
          Text(
            "Tasks",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
        ],
      ),
      onSelected: (int value) {
        if (value == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(
                currentUser: currentUser,
                onLogout: onLogout,
              ),
            ),
          );
        } else if (value == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StatsScreen(
                currentUser: currentUser,
                onLogout: onLogout,
              ),
            ),
          );
        } else if (value == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalStatsScreen(
                username: currentUser,
                onLogout: onLogout,
              ),
            ),
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: const [
              Icon(Icons.dashboard, size: 18, color: Colors.black87),
              SizedBox(width: 4),
              Text("Dashboard", style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: const [
              Icon(Icons.bar_chart, size: 18, color: Colors.black87),
              SizedBox(width: 4),
              Text("Statistiken", style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Row(
            children: const [
              Icon(Icons.person, size: 18, color: Colors.black87),
              SizedBox(width: 4),
              Text("Pers. Stats", style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  /// Generic bottom bar item builder for unused pages.
  Widget _buildBottomBarItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _buildTasksButton(context)),
          Expanded(
            child: _buildBottomBarItem(
              context: context,
              icon: Icons.work,
              label: "Projects",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Projects – Coming soon")),
                );
              },
            ),
          ),
          Expanded(
            child: _buildBottomBarItem(
              context: context,
              icon: Icons.description,
              label: "SOPs",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("SOPs – Coming soon")),
                );
              },
            ),
          ),
          Expanded(
            child: _buildBottomBarItem(
              context: context,
              icon: Icons.note,
              label: "Notes",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Notes – Coming soon")),
                );
              },
            ),
          ),
          Expanded(
            child: _buildBottomBarItem(
              context: context,
              icon: Icons.account_circle,
              label: "Konto",
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyAccountScreen(
                      currentUser: currentUser,
                      onLogout: onLogout,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
