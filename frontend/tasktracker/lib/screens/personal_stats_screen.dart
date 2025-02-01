// lib/screens/personal_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Dummy data classes for personal stats charts
class UserTaskCategory {
  final String category;
  final int count;
  UserTaskCategory(this.category, this.count);
}

class DailyUserPerformance {
  final DateTime day;
  final int tasksCompleted;
  DailyUserPerformance(this.day, this.tasksCompleted);
}

class PersonalStatsScreen extends StatefulWidget {
  final String username;
  final VoidCallback onLogout;

  const PersonalStatsScreen({
    Key? key,
    required this.username,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<PersonalStatsScreen> createState() => _PersonalStatsScreenState();
}

class _PersonalStatsScreenState extends State<PersonalStatsScreen> {
  // Summary stats (dummy data)
  final int totalDone = 20;
  final String avgTime = "8h";
  final String favoriteTask = "Küche";
  final int favoriteCount = 10;
  final String leastFavTask = "kochen";
  final int leastFavCount = 2;

  // Chart data variables
  late List<PieChartSectionData> _categoryPieSections;
  late List<BarChartGroupData> _dailyPerformanceBarGroups;
  late List<FlSpot> _tasksOverTimeSpots;

  @override
  void initState() {
    super.initState();
    _buildChartData();
  }

  void _buildChartData() {
    // Build dummy pie chart data: distribution of tasks by category for the user
    final userCategories = [
      UserTaskCategory("Wäsche", 6),
      UserTaskCategory("Küche", 8),
      UserTaskCategory("kochen", 4),
      UserTaskCategory("Sonstiges", 2),
    ];
    _categoryPieSections = _buildPieSections(userCategories);

    // Build dummy daily performance data for the last 7 days
    final now = DateTime.now();
    final dailyData = <DailyUserPerformance>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      dailyData.add(DailyUserPerformance(day, (i * 2) + 1)); // dummy values
    }
    _dailyPerformanceBarGroups = _buildDailyBarGroups(dailyData);

    // Build dummy tasks over time data (line chart)
    final firstDay = now.subtract(Duration(days: 6));
    _tasksOverTimeSpots = [];
    for (int i = 0; i < 7; i++) {
      _tasksOverTimeSpots.add(FlSpot(i.toDouble(), (i * 2 + 1).toDouble())); // dummy values
    }
  }

  List<PieChartSectionData> _buildPieSections(List<UserTaskCategory> data) {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final percentage = total == 0 ? 0 : (item.count / total * 100);
      sections.add(
        PieChartSectionData(
          color: _pickColor(i),
          value: item.count.toDouble(),
          title: "${item.category}\n${percentage.toStringAsFixed(1)}%",
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  List<BarChartGroupData> _buildDailyBarGroups(List<DailyUserPerformance> data) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[i].tasksCompleted.toDouble(),
              color: _pickColor(i),
              width: 16,
            )
          ],
        ),
      );
    }
    return groups;
  }

  Color _pickColor(int index) {
    const colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Persönliche Statistiken für ${widget.username}"),
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 2,
        currentUser: widget.username,
        onLogout: widget.onLogout,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Benutzer: ${widget.username}",
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
            const SizedBox(height: 16),
            // Pie Chart Card: Distribution by Category
            Card(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Aufgaben nach Kategorie",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: _categoryPieSections,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Bar Chart Card: Daily Performance
            Card(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tägliche Leistung",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          barGroups: _dailyPerformanceBarGroups,
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= 7) return const SizedBox();
                                  final day = DateTime.now().subtract(Duration(days: 6 - index));
                                  final dayLabel = DateFormat('EE', 'de_DE').format(day);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      dayLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Line Chart Card: Tasks over Time
            Card(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Aufgaben im Zeitverlauf",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: _tasksOverTimeSpots,
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Export Buttons
            ElevatedButton(
              onPressed: () => _launchUrl(ApiService.getCsvExportUrl()),
              child: const Text("Export as CSV"),
            ),
            ElevatedButton(
              onPressed: () => _launchUrl(ApiService.getXlsxExportUrl()),
              child: const Text("Export as XLSX"),
            ),
          ],
        ),
      ),
    );
  }
}
