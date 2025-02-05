import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:math';

/// Data class for grouping tasks by category.
class UserTaskCategory {
  final String category;
  final int count;
  UserTaskCategory(this.category, this.count);
}

/// Data class for daily performance.
class DailyUserPerformance {
  final DateTime day;
  final int tasksCompleted;
  DailyUserPerformance(this.day, this.tasksCompleted);
}

/// PersonalStatsScreen now fetches real data (from the general stats API)
/// and then filters for the current user.
class PersonalStatsScreen extends StatefulWidget {
  final String username;
  final String currentGroupId; // NEW: Add currentGroupId here
  final VoidCallback onLogout;

  const PersonalStatsScreen({
    Key? key,
    required this.username,
    required this.currentGroupId,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<PersonalStatsScreen> createState() => _PersonalStatsScreenState();
}

class _PersonalStatsScreenState extends State<PersonalStatsScreen> {
  bool _loading = false;

  // Summary stats (computed from the filtered tasks)
  int totalDone = 0;
  String avgTime = "0h";
  String favoriteTask = "Unbekannt";
  int favoriteCount = 0;
  String leastFavTask = "Unbekannt";
  int leastFavCount = 0;

  // Chart data variables for this user
  List<PieChartSectionData> _categoryPieSections = [];
  List<BarChartGroupData> _dailyPerformanceBarGroups = [];
  List<FlSpot> _tasksOverTimeSpots = [];

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
  }

  /// Fetch overall stats from the API and filter the tasks
  /// to those completed by the logged‐in user.
  Future<void> _fetchUserStats() async {
    setState(() => _loading = true);
    try {
      // Get overall stats from the API. Pass the group id.
      final statsResponse = await ApiService.getStats(widget.currentGroupId);

      // Filter the "all_tasks" list to those completed by the current user.
      final List<dynamic> allTasks = statsResponse.allTasksRaw;
      final userTasks = allTasks.where((t) {
        return t["completed"] == 1 &&
            t["completed_by"] != null &&
            t["completed_by"].toString().toLowerCase() == widget.username.toLowerCase();
      }).toList();

      totalDone = userTasks.length;

      // Compute average completion time (in hours)
      double totalHours = 0;
      for (var t in userTasks) {
        try {
          final created = DateTime.parse(t["creation_date"]).toLocal();
          final completed = DateTime.parse(t["completed_on"]).toLocal();
          totalHours += completed.difference(created).inMinutes / 60.0;
        } catch (e) {
          // Skip tasks with parsing errors
        }
      }
      avgTime = totalDone > 0 ? "${(totalHours / totalDone).round()}h" : "0h";

      // Compute frequency of tasks by title (to derive favorite and least fav)
      Map<String, int> taskCounts = {};
      for (var t in userTasks) {
        final title = t["title"] ?? "Unbekannt";
        taskCounts[title] = (taskCounts[title] ?? 0) + 1;
      }
      if (taskCounts.isNotEmpty) {
        // Favorite: highest count
        var favEntry = taskCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
        favoriteTask = favEntry.key;
        favoriteCount = favEntry.value;
        // Least favorite: lowest count (if there’s more than one task)
        var leastEntry = taskCounts.entries.reduce((a, b) => a.value <= b.value ? a : b);
        leastFavTask = leastEntry.key;
        leastFavCount = leastEntry.value;
      } else {
        favoriteTask = "Unbekannt";
        favoriteCount = 0;
        leastFavTask = "Unbekannt";
        leastFavCount = 0;
      }

      // Build chart data based on the userTasks list.
      _buildCharts(userTasks);
    } catch (e) {
      debugPrint("Error fetching personal stats: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _buildCharts(List<dynamic> userTasks) {
    // Build Pie Chart Data: Distribution by Category.
    Map<String, int> categoryCounts = {
      "Wäsche": 0,
      "Küche": 0,
      "kochen": 0,
      "Sonstiges": 0,
    };
    for (var t in userTasks) {
      final title = t["title"].toString().toLowerCase();
      if (title.contains("wäsche")) {
        categoryCounts["Wäsche"] = categoryCounts["Wäsche"]! + 1;
      } else if (title.contains("küche")) {
        categoryCounts["Küche"] = categoryCounts["Küche"]! + 1;
      } else if (title.contains("kochen")) {
        categoryCounts["kochen"] = categoryCounts["kochen"]! + 1;
      } else {
        categoryCounts["Sonstiges"] = categoryCounts["Sonstiges"]! + 1;
      }
    }
    List<UserTaskCategory> userCategories = [];
    categoryCounts.forEach((cat, count) {
      userCategories.add(UserTaskCategory(cat, count));
    });
    _categoryPieSections = _buildPieSections(userCategories);

    // Build Daily Performance Data for the last 7 days.
    final now = DateTime.now();
    Map<String, int> dailyCounts = {};
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat("yyyy-MM-dd").format(day);
      dailyCounts[key] = 0;
    }
    for (var t in userTasks) {
      try {
        final completed = DateTime.parse(t["completed_on"]).toLocal();
        final key = DateFormat("yyyy-MM-dd").format(completed);
        if (dailyCounts.containsKey(key)) {
          dailyCounts[key] = dailyCounts[key]! + 1;
        }
      } catch (e) {
        // ignore parse errors
      }
    }
    List<DailyUserPerformance> dailyData = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat("yyyy-MM-dd").format(day);
      dailyData.add(DailyUserPerformance(day, dailyCounts[key] ?? 0));
    }
    _dailyPerformanceBarGroups = _buildDailyBarGroups(dailyData);

    // Build Tasks Over Time Data (line chart) using the dailyData.
    _tasksOverTimeSpots = [];
    for (int i = 0; i < dailyData.length; i++) {
      _tasksOverTimeSpots.add(FlSpot(i.toDouble(), dailyData[i].tasksCompleted.toDouble()));
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
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.55,
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
              width: 22,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          // This makes the tooltip value available for topTitles.
          showingTooltipIndicators: [0],
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

  // ---------- UI Helper Widgets ----------

  /// Summary card displaying key personal statistics.
  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Benutzer: ${widget.username}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("Insgesamt erledigt: $totalDone", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text("Durchschnittliche Zeit pro Aufgabe: $avgTime",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text("Lieblingsaufgabe: $favoriteTask ($favoriteCount mal)",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text("Unbeliebteste Aufgabe: $leastFavTask ($leastFavCount mal)",
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// Pie chart card for tasks by category.
  Widget _buildCategoryPieChartCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 340,
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
    );
  }

  /// Bar chart card for daily performance with permanent value labels.
  Widget _buildDailyPerformanceBarChartCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tägliche Leistung",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: _dailyPerformanceBarGroups,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(6),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          rod.toY.toInt().toString(),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      },
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= 7) return const SizedBox.shrink();
                          final day = DateTime.now().subtract(Duration(days: 6 - index));
                          final dayLabel = DateFormat('EE', 'de_DE').format(day);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dayLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _dailyPerformanceBarGroups.length) {
                            return const SizedBox.shrink();
                          }
                          final barValue = _dailyPerformanceBarGroups[index].barRods.first.toY;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              barValue.toInt().toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Line chart card for tasks over time.
  Widget _buildTasksOverTimeLineChartCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Aufgaben im Zeitverlauf",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _tasksOverTimeSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Main Build ----------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Persönliche Statistiken")),
        bottomNavigationBar: CustomBottomBar(
          selectedIndex: 2,
          currentUser: widget.username,
          currentGroupId: widget.currentGroupId,
          onLogout: widget.onLogout,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Persönliche Statistiken für ${widget.username}"),
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 2,
        currentUser: widget.username,
        currentGroupId: widget.currentGroupId,
        onLogout: widget.onLogout,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;
          // On wider screens, show two cards per row; on narrow screens, cards take full width.
          final double cardWidth = availableWidth < 600 ? availableWidth : (availableWidth / 2) - 24;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    Container(width: cardWidth, child: _buildCategoryPieChartCard()),
                    Container(width: cardWidth, child: _buildDailyPerformanceBarChartCard()),
                    Container(width: cardWidth, child: _buildTasksOverTimeLineChartCard()),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
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
              ],
            ),
          );
        },
      ),
    );
  }
}
