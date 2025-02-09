import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/stats_response.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';

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

/// Updated StatsScreen with a modern, spacious, uncluttered design.
class StatsScreen extends StatefulWidget {
  final String currentUser;
  final String currentGroupId; // NEW: Add group id here
  final VoidCallback onLogout;
  const StatsScreen({
    Key? key,
    required this.currentUser,
    required this.currentGroupId,
    required this.onLogout,
  }) : super(key: key);

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
  List<LineChartBarData> _multiLineBarData = [];

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
      // Use the passed-in group id from widget.currentGroupId
      final resp = await ApiService.getStats(widget.currentGroupId);
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
    final tasksList = taskCounts.entries
        .map((e) => TaskTypeCountChart(e.key, e.value))
        .toList();
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
          titlePositionPercentageOffset: 0.55,
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
              width: 22,
              borderRadius: BorderRadius.circular(4),
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
              width: 22,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }
    return groups;
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
              width: 22,
              borderRadius: BorderRadius.circular(4),
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
      barWidth: 3,
      dotData: FlDotData(show: true),
    );

    final otterLine = LineChartBarData(
      spots: otterSpots,
      isCurved: true,
      color: Colors.red,
      barWidth: 3,
      dotData: FlDotData(show: true),
    );

    return [wieselLine, otterLine];
  }

  // ---------- MODERN & RESPONSIVE LAYOUT ----------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Statistiken")),
        bottomNavigationBar: CustomBottomBar(
          selectedIndex: _selectedBottomIndex,
          currentUser: widget.currentUser,
          currentGroupId: widget.currentGroupId,
          onLogout: widget.onLogout,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Statistiken")),
        bottomNavigationBar: CustomBottomBar(
          selectedIndex: _selectedBottomIndex,
          currentUser: widget.currentUser,
          currentGroupId: widget.currentGroupId,
          onLogout: widget.onLogout,
        ),
        body: const Center(child: Text("No stats loaded.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistiken (fl_chart)"),
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: _selectedBottomIndex,
        currentUser: widget.currentUser,
        currentGroupId: widget.currentGroupId,
        onLogout: widget.onLogout,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;
          final double cardWidth = availableWidth < 600 ? availableWidth : (availableWidth / 2) - 24;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimePeriodCard(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    Container(width: cardWidth, child: _buildCompletionCountsCard()),
                    Container(
                      width: cardWidth,
                      child: _buildBarChartCard(
                        title: "Durchschnittliche Erledigungszeit (Stunden)",
                        barGroups: _avgTimeBarGroups,
                        labels: const ["Wiesel", "Otter"],
                      ),
                    ),
                    Container(
                      width: cardWidth,
                      child: _buildBarChartCard(
                        title: "Meistabgeschlossene Aufgaben (Top 5)",
                        barGroups: _mostCompletedBarGroups,
                        labels: _mostCompletedBarGroups.map((_) => "").toList(),
                      ),
                    ),
                    Container(
                      width: cardWidth,
                      child: _buildLineChartCard(
                        title: "Abgeschlossene Aufgaben über Zeit",
                        spots: _tasksOverTimeSpots,
                      ),
                    ),
                    Container(
                      width: cardWidth,
                      child: _buildBarChartCard(
                        title: "Aufgaben pro Wochentag",
                        barGroups: _dayOfWeekBarGroups,
                        labels: const ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"],
                      ),
                    ),
                    Container(
                      width: cardWidth,
                      child: _buildMultiLineChartCard(
                        title: "Mehrlinien-Vergleich (Wiesel vs Otter)",
                        lines: _multiLineBarData,
                      ),
                    ),
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

  // ---------- Helper Widgets ----------

  /// Card for selecting the statistics time period and displaying summary numbers.
  Widget _buildTimePeriodCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Statistiken (Zeitraum)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("Zeitraum: ", style: TextStyle(fontSize: 16)),
                DropdownButton<String>(
                  value: _selectedStatRange,
                  items: _statRanges.map((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 16)),
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
            const SizedBox(height: 16),
            Text(
              "Aufgaben zugewiesen ($_selectedStatRange):",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4),
              child: Text("• Wiesel: 3", style: TextStyle(fontSize: 15)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 2),
              child: Text("• Otter: 4", style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 12),
            Text(
              "Aufgaben erledigt ($_selectedStatRange):",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4),
              child: Text("• Wiesel: 2", style: TextStyle(fontSize: 15)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 2),
              child: Text("• Otter: 5", style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 12),
            Text(
              "Durchschnittliche Bearbeitungszeit ($_selectedStatRange):",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4),
              child: Text("• Wiesel: 12h", style: TextStyle(fontSize: 15)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 2),
              child: Text("• Otter: 9h", style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  /// Card listing who has completed how many tasks.
  Widget _buildCompletionCountsCard() {
    if (_stats!.completions.isEmpty) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text("No completions found"),
        ),
      );
    }
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Wer hat wie viele Aufgaben erledigt?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._stats!.completions.map((c) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                title: Text(c.completedBy, style: const TextStyle(fontSize: 16)),
                trailing: Text(c.totalCompleted.toString(), style: const TextStyle(fontSize: 16)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Bar chart card with permanent value labels and modern styling.
  Widget _buildBarChartCard({
    required String title,
    required List<BarChartGroupData> barGroups,
    List<String>? labels,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
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
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: labels != null && labels.isNotEmpty,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= (labels?.length ?? 0)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
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

  /// Line chart card with modern styling.
  Widget _buildLineChartCard({
    required String title,
    required List<FlSpot> spots,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
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

  /// Multi-line chart card.
  Widget _buildMultiLineChartCard({
    required String title,
    required List<LineChartBarData> lines,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: lines,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
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
