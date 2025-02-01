// lib/screens/stats_screen.dart, do not remove this line!

import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/stats_response.dart';
import 'package:flutter_tasktracker/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_tasktracker/screens/dashboard_screen.dart';
import 'package:flutter_tasktracker/screens/personal_stats_screen.dart';

// Data classes for intermediate chart logic
class CompletionCountChart {
  final String user;
  final int count;
  CompletionCountChart(this.user, this.count);
}

class CompletionTimeChart {
  final String user;
  final int hours;
  CompletionTimeChart(this.user, this.hours);
}

class TaskTypeCountChart {
  final String title;
  final int count;
  TaskTypeCountChart(this.title, this.count);
}

class TasksOverTime {
  final DateTime day;
  final int count;
  TasksOverTime(this.day, this.count);
}

class DayOfWeekCountChart {
  final String day;
  final int count;
  DayOfWeekCountChart(this.day, this.count);
}

class MultiLineActivity {
  final DateTime date;
  final int value;
  MultiLineActivity(this.date, this.value);
}

// Updated StatsScreen now accepts currentUser and onLogout so it can pass them to the bottom bar.
class StatsScreen extends StatefulWidget {
  final String currentUser;
  final VoidCallback onLogout;
  const StatsScreen({Key? key, required this.currentUser, required this.onLogout})
      : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _loading = false;
  StatsResponse? _stats;

  /// Zeitraum (range) dropdown values.
  final List<String> _statRanges = [
    "Letzte 7 Tage",
    "Seit Montag",
    "Letzte 14 Tage",
    "Letzte 30 Tage",
    "Aktueller Monat",
  ];
  String _selectedStatRange = "Letzte 7 Tage";

  // Chart data variables
  List<PieChartSectionData> _pieSections = [];
  List<BarChartGroupData> _avgTimeBarGroups = [];
  List<BarChartGroupData> _mostCompletedBarGroups = [];
  List<FlSpot> _tasksOverTimeSpots = []; // single line
  List<BarChartGroupData> _dayOfWeekBarGroups = [];
  List<LineChartBarData> _multiLineBarData = []; // multi-line

  // The selected bottom bar index.
  // For StatsScreen, we want the "Statistiken" tab (index 1) to be highlighted.
  int _selectedBottomIndex = 1;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService.getStats();
      setState(() => _stats = resp);
      _buildCharts(resp);
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _buildCharts(StatsResponse resp) {
    // 1) Pie Chart: Who completed how many tasks
    final completions = <CompletionCountChart>[];
    for (var c in resp.completions) {
      final user = c.completedBy.isEmpty ? "Unbekannt" : c.completedBy;
      completions.add(CompletionCountChart(user, c.totalCompleted));
    }
    _pieSections = _buildPieSections(completions);

    // 2) Bar Chart: Average completion times (example data)
    final avgTimeData = <CompletionTimeChart>[
      CompletionTimeChart("Wiesel", 12),
      CompletionTimeChart("Otter", 9),
    ];
    _avgTimeBarGroups = _buildAvgTimeBarGroups(avgTimeData);

    // 3) Bar Chart: Most completed tasks
    final Map<String, int> taskCounts = {};
    for (var t in resp.allTasksRaw) {
      if (t["completed"] == 1) {
        final title = t["title"] ?? "Unbekannt";
        taskCounts[title] = (taskCounts[title] ?? 0) + 1;
      }
    }
    final tasksList = taskCounts.entries.map((e) => TaskTypeCountChart(e.key, e.value)).toList();
    tasksList.sort((a, b) => b.count.compareTo(a.count));
    final top5 = tasksList.take(5).toList();
    _mostCompletedBarGroups = _buildMostCompletedBarGroups(top5);

    // 4) Single line: Tasks over time (dummy data)
    final now = DateTime.now();
    final tasksOverTimeData = <TasksOverTime>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final count = (i * 2) + 1;
      tasksOverTimeData.add(TasksOverTime(day, count));
    }
    _tasksOverTimeSpots = _buildLineSpots(tasksOverTimeData);

    // 5) Bar Chart: Tasks per day-of-week (dummy data)
    final dayOfWeekData = <DayOfWeekCountChart>[
      DayOfWeekCountChart("Mo", 3),
      DayOfWeekCountChart("Di", 5),
      DayOfWeekCountChart("Mi", 2),
      DayOfWeekCountChart("Do", 6),
      DayOfWeekCountChart("Fr", 4),
      DayOfWeekCountChart("Sa", 1),
      DayOfWeekCountChart("So", 2),
    ];
    _dayOfWeekBarGroups = _buildDayOfWeekBarGroups(dayOfWeekData);

    // 6) Multi-line chart (Wiesel vs Otter)
    final wieselLine = <MultiLineActivity>[];
    final otterLine = <MultiLineActivity>[];
    for (int i = 5; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      wieselLine.add(MultiLineActivity(day, (i * 2) + 2));
      otterLine.add(MultiLineActivity(day, (i * 3) + 1));
    }
    _multiLineBarData = _buildMultiLineData(wieselLine, otterLine);
  }

  // ---------- BUILD PIE DATA ----------
  List<PieChartSectionData> _buildPieSections(List<CompletionCountChart> data) {
    if (data.isEmpty) return [];
    final total = data.fold<int>(0, (sum, c) => sum + c.count);
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final double percentage = total == 0 ? 0 : (item.count / total * 100);
      final color = _pickColor(i);
      sections.add(
        PieChartSectionData(
          color: color,
          value: item.count.toDouble(),
          title: "${item.user}\n${percentage.toStringAsFixed(1)}%",
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  // ---------- BUILD BAR DATA (Average Time) ----------
  List<BarChartGroupData> _buildAvgTimeBarGroups(List<CompletionTimeChart> data) {
    if (data.isEmpty) return [];
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: item.hours.toDouble(),
              color: _pickColor(i),
              width: 20,
              borderRadius: BorderRadius.zero,
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }
    return groups;
  }

  // ---------- BUILD BAR DATA (Most Completed Tasks) ----------
  List<BarChartGroupData> _buildMostCompletedBarGroups(List<TaskTypeCountChart> data) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: item.count.toDouble(),
              color: _pickColor(i),
              width: 20,
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }
    return groups;
  }

  // ---------- BUILD SINGLE LINE DATA (Tasks Over Time) ----------
  List<FlSpot> _buildLineSpots(List<TasksOverTime> data) {
    if (data.isEmpty) return [];
    data.sort((a, b) => a.day.compareTo(b.day));
    final spots = <FlSpot>[];
    final firstDay = data.first.day;
    for (var e in data) {
      final diff = e.day.difference(firstDay).inDays.toDouble();
      spots.add(FlSpot(diff, e.count.toDouble()));
    }
    return spots;
  }

  // ---------- BUILD BAR DATA (Day of Week) ----------
  List<BarChartGroupData> _buildDayOfWeekBarGroups(List<DayOfWeekCountChart> data) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: item.count.toDouble(),
              color: _pickColor(i),
              width: 20,
            ),
          ],
        ),
      );
    }
    return groups;
  }

  // ---------- BUILD MULTI-LINE DATA (Wiesel vs Otter) ----------
  List<LineChartBarData> _buildMultiLineData(
    List<MultiLineActivity> wiesel,
    List<MultiLineActivity> otter,
  ) {
    if (wiesel.isEmpty && otter.isEmpty) return [];
    wiesel.sort((a, b) => a.date.compareTo(b.date));
    otter.sort((a, b) => a.date.compareTo(b.date));

    final firstDay = (wiesel.isNotEmpty ? wiesel.first.date : otter.first.date);

    final wieselSpots = <FlSpot>[];
    for (var e in wiesel) {
      final diff = e.date.difference(firstDay).inDays.toDouble();
      wieselSpots.add(FlSpot(diff, e.value.toDouble()));
    }
    final otterSpots = <FlSpot>[];
    for (var e in otter) {
      final diff = e.date.difference(firstDay).inDays.toDouble();
      otterSpots.add(FlSpot(diff, e.value.toDouble()));
    }

    final wieselLine = LineChartBarData(
      spots: wieselSpots,
      isCurved: true,
      color: Colors.blue,
      barWidth: 2,
    );

    final otterLine = LineChartBarData(
      spots: otterSpots,
      isCurved: true,
      color: Colors.red,
      barWidth: 2,
    );

    return [wieselLine, otterLine];
  }

  // ---------- BOTTOM BAR ----------
  Widget _buildBottomBar() {
    return Container(
      height: 60,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomBarItem(
            index: 0,
            icon: Icons.dashboard,
            label: "Dashboard",
            onTapOverride: () {
              setState(() {
                _selectedBottomIndex = 0;
              });
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardScreen(
                    currentUser: widget.currentUser,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
          ),
          _buildBottomBarItem(
            index: 1,
            icon: Icons.bar_chart,
            label: "Statistiken",
            onTapOverride: () {
              // Already on StatsScreen; do nothing.
            },
          ),
          _buildBottomBarItem(
            index: 2,
            icon: Icons.person,
            label: "Pers. Stats",
            onTapOverride: () {
              setState(() {
                _selectedBottomIndex = 2;
              });
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonalStatsScreen(
                    username: widget.currentUser,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBarItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTapOverride,
  }) {
    final bool isSelected = (_selectedBottomIndex == index);
    return InkWell(
      onTap: onTapOverride,
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

  // ---------- NAVIGATION HELPER ----------
  void _goToUserStats(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalStatsScreen(
          username: username,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  // ---------- BUILD (SINGLE BUILD METHOD) ----------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Statistiken")),
        bottomNavigationBar: _buildBottomBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Statistiken")),
        bottomNavigationBar: _buildBottomBar(),
        body: const Center(child: Text("No stats loaded.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistiken (fl_chart)"),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1) Zeitraum section (old Dashboard style)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Statistiken (Zeitraum)",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Zeitraum: "),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedStatRange,
                          items: _statRanges.map((s) {
                            return DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedStatRange = val ?? "Letzte 7 Tage";
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Aufgaben zugewiesen ($_selectedStatRange):",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text("• Wiesel: 3"),
                    const Text("• Otter: 4"),
                    const SizedBox(height: 10),
                    Text("Aufgaben erledigt ($_selectedStatRange):",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text("• Wiesel: 2"),
                    const Text("• Otter: 5"),
                    const SizedBox(height: 10),
                    Text("Durchschnittliche Bearbeitungszeit ($_selectedStatRange):",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text("• Wiesel: 12h"),
                    const Text("• Otter: 9h"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 2) Who completed how many
            _buildCompletionCountsCard(),
            const SizedBox(height: 16),
            // 3) Bar chart for average time
            _buildBarChartCard(
              title: "Durchschnittliche Erledigungszeit (Stunden)",
              barGroups: _avgTimeBarGroups,
              labels: ["Wiesel", "Otter"],
            ),
            const SizedBox(height: 16),
            // 4) Bar chart for most completed tasks
            _buildBarChartCard(
              title: "Meistabgeschlossene Aufgaben (Top 5)",
              barGroups: _mostCompletedBarGroups,
              labels: _mostCompletedBarGroups.map((_) => "").toList(),
            ),
            const SizedBox(height: 16),
            // 5) Single line chart
            _buildLineChartCard(
              title: "Abgeschlossene Aufgaben über Zeit",
              spots: _tasksOverTimeSpots,
            ),
            const SizedBox(height: 16),
            // 6) Day-of-week bar chart
            _buildBarChartCard(
              title: "Aufgaben pro Wochentag",
              barGroups: _dayOfWeekBarGroups,
              labels: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"],
            ),
            const SizedBox(height: 16),
            // 7) Multi-line chart
            _buildMultiLineChartCard(
              title: "Mehrlinien-Vergleich (Wiesel vs Otter)",
              lines: _multiLineBarData,
            ),
            const SizedBox(height: 16),
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

  // ---------- Helper Widgets ----------

  Widget _buildCompletionCountsCard() {
    if (_stats!.completions.isEmpty) {
      return Card(
        elevation: 3,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text("No completions found"),
        ),
      );
    }
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Wer hat wie viele Aufgaben erledigt?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._stats!.completions.map((c) {
              return ListTile(
                title: Text(c.completedBy),
                trailing: Text(c.totalCompleted.toString()),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard({
    required String title,
    required List<BarChartGroupData> barGroups,
    List<String>? labels,
  }) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: labels != null && labels.isNotEmpty,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= (labels?.length ?? 0)) {
                            return Container();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8), // adds space below bars
                            child: Text(
                              labels![idx],
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
    );
  }

  Widget _buildLineChartCard({
    required String title,
    required List<FlSpot> spots,
  }) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
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
    );
  }

  Widget _buildMultiLineChartCard({
    required String title,
    required List<LineChartBarData> lines,
  }) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: lines,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
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
    );
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
}
