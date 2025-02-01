// lib/widgets/custom_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/screens/dashboard_screen.dart';
import 'package:flutter_tasktracker/screens/stats_screen.dart';
import 'package:flutter_tasktracker/screens/personal_stats_screen.dart';

class CustomBottomBar extends StatelessWidget {
  final int selectedIndex;
  final String currentUser;
  final VoidCallback onLogout;

  const CustomBottomBar({
    Key? key,
    required this.selectedIndex,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  Widget _buildBottomBarItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = (selectedIndex == index);
    return InkWell(
      onTap: () {
        if (!isSelected) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  currentUser: currentUser,
                  onLogout: onLogout,
                ),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StatsScreen(
                  currentUser: currentUser,
                  onLogout: onLogout,
                ),
              ),
            );
          } else if (index == 2) {
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
        }
      },
      child: Container(
        width: 80,
        color: isSelected ? Colors.grey.shade300 : Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomBarItem(
              context: context, index: 0, icon: Icons.dashboard, label: "Dashboard"),
          _buildBottomBarItem(
              context: context, index: 1, icon: Icons.bar_chart, label: "Statistiken"),
          _buildBottomBarItem(
              context: context, index: 2, icon: Icons.person, label: "Pers. Stats"),
        ],
      ),
    );
  }
}
