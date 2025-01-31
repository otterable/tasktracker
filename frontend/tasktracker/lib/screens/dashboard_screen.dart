// lib/screens/dashboard_screen.dart, do not remove this line!

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/screens/stats_screen.dart';
import 'package:flutter_tasktracker/screens/personal_stats_screen.dart'; // For user-specific stats
import 'package:flutter_tasktracker/utils.dart';

class DashboardScreen extends StatefulWidget {
  final String currentUser;
  final VoidCallback onLogout;

  const DashboardScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // All tasks from server
  List<Task> allTasks = [];

  // Fields for creating a new task
  String _selectedTitle = "Wäsche";
  final List<String> _taskTitles = ["Wäsche", "Küche", "kochen", "Custom"];
  final _customTitleController = TextEditingController();

  int _selectedDuration = 48;
  final List<int> _durations = [12, 24, 48, 72];

  String? _assignedTo;
  final List<String?> _assignments = [null, "Wiesel", "Otter"];

  // For monthly calendar
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // For stats date ranges
  final List<String> _statRanges = [
    "Letzte 7 Tage",
    "Seit Montag",
    "Letzte 14 Tage",
    "Letzte 30 Tage",
    "Aktueller Monat",
  ];
  String _selectedStatRange = "Letzte 7 Tage";
  String _selectedCompletedRange = "Letzte 7 Tage";

  // Toggles for expansions
  bool _showWieselStats = false;
  bool _showOtterStats = false;

  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
  }

  Future<void> _fetchAllTasks() async {
    try {
      final tasks = await ApiService.getAllTasks();
      setState(() {
        allTasks = tasks;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Aufgaben: $e");
    }
  }

  // Creating a new task
  void _createTask() async {
    String title;
    if (_selectedTitle == "Custom") {
      title = _customTitleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bitte einen eigenen Tasknamen eingeben.")),
        );
        return;
      }
    } else {
      title = _selectedTitle;
    }

    try {
      final newTask = await ApiService.createTask(title, _selectedDuration, _assignedTo);
      await _fetchAllTasks();

      final assigned = newTask.assignedTo;
      if (assigned != null && assigned.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aufgabe '$title' wurde $assigned zugewiesen!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aufgabe '$title' erstellt (niemand zugewiesen).")),
        );
      }

      // Clear custom field
      _customTitleController.clear();
    } catch (e) {
      debugPrint("Fehler beim Erstellen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Erstellen.")),
      );
    }
  }

  // Mark task as finished
  void _finishTask(Task task) async {
    try {
      final updated = await ApiService.finishTask(task.id, widget.currentUser);
      await _fetchAllTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${updated.title}' von ${updated.completedBy} erledigt.")),
      );
    } catch (e) {
      debugPrint("Fehler beim Abschließen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Abschließen.")),
      );
    }
  }

  // Navigate to the previous month in the calendar
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  // Navigate to the next month in the calendar
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  // Filter completed tasks if needed
  List<Task> _filterCompletedTasks(List<Task> completed) {
    // Real logic for _selectedCompletedRange could go here
    return completed;
  }

  // Navigate to personal stats screen
  void _goToUserStats(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PersonalStatsScreen(username: username)),
    );
  }

  // Show a popup with task info when user taps a calendar item
  void _showTaskDialog(Task task) {
    final isCompleted = (task.completed == 1);
    final taskColor = _getTaskColor(task.title); // For the top line color

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          // Rounded corners overall
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white, // White background at full opacity
          // Build a custom title that includes a thick colored strip at the top
          titlePadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thick colored line at the top
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: taskColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              // Actual title text below the colored bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  "Aufgabe: ${task.title}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assigned To
                if (task.assignedTo != null && task.assignedTo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Zugewiesen an: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: task.assignedTo!,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Erstellt am
                if (task.creationDate != null)
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Erstellt am: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: Utils.formatDateTime(task.creationDate),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                // Fällig bis
                if (task.dueDate != null)
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Fällig bis: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: Utils.formatDateTime(task.dueDate),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // Status Completed or Not
                if (isCompleted)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Status: ABGESCHLOSSEN",
                        style: TextStyle(color: Colors.green),
                      ),
                      // Abgeschlossen von
                      if (task.completedBy != null)
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: "Abgeschlossen von: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: task.completedBy!,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      // Erledigt am
                      if (task.completedOn != null)
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: "Erledigt am: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: Utils.formatDateTime(task.completedOn),
                                style: const TextStyle(color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  const Text("Status: Offen", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            if (!isCompleted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50), // green color
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  _finishTask(task);
                },
                child: const Text("Fertigstellen"),
              ),
            // Schliessen button with #D62728, white bold font
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Schliessen",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final offeneAufgaben = allTasks.where((t) => t.completed == 0).toList();
    final completedTasks = allTasks.where((t) => t.completed == 1).toList();
    final erledigteAufgaben = _filterCompletedTasks(completedTasks);

    // Decide if wide screen or not
    final maxWidth = MediaQuery.of(context).size.width;
    final bool wideScreen = maxWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text("Willkommen, ${widget.currentUser}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Possibly place "Neue Aufgabe" + Stats side by side if wide, else stacked
            if (wideScreen)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildCreateTaskCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatsSection()),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCreateTaskCard(),
                  const SizedBox(height: 16),
                  _buildStatsSection(),
                ],
              ),
            const SizedBox(height: 16),

            // Calendar
            _buildMonthlyCalendar(),
            const SizedBox(height: 16),

            // Offene + Erledigte side by side if wide
            if (wideScreen)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildOffeneAufgabenListe(offeneAufgaben)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildErledigteAufgaben(erledigteAufgaben)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOffeneAufgabenListe(offeneAufgaben),
                  const SizedBox(height: 16),
                  _buildErledigteAufgaben(erledigteAufgaben),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // --- CREATE TASK CARD ---
  Widget _buildCreateTaskCard() {
    return Card(
      elevation: 4,
      color: const Color(0xFF02569D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Neue Aufgabe erstellen",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Aufgabe:", style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  dropdownColor: const Color(0xFF02569D),
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  value: _taskTitles.contains(_selectedTitle) ? _selectedTitle : "Wäsche",
                  items: _taskTitles.map((t) {
                    return DropdownMenuItem<String>(
                      value: t,
                      child: Text(t, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTitle = val ?? "Wäsche";
                    });
                  },
                ),
                if (_selectedTitle == "Custom") ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _customTitleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Eigener Name",
                        labelStyle: TextStyle(color: Colors.white70),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Dauer (h):", style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  dropdownColor: const Color(0xFF02569D),
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  value: _selectedDuration,
                  items: _durations.map((d) {
                    return DropdownMenuItem<int>(
                      value: d,
                      child: Text("$d", style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDuration = val ?? 48;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Zuweisen an:", style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  dropdownColor: const Color(0xFF02569D),
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  value: _assignments.contains(_assignedTo) ? _assignedTo : null,
                  items: _assignments.map((p) {
                    final display = p ?? "Niemand";
                    return DropdownMenuItem<String?>(
                      value: p,
                      child: Text(display, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _assignedTo = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _createTask,
              child: const Text("Speichern"),
            ),
          ],
        ),
      ),
    );
  }

  // --- QUICK STATS ---
  Widget _buildStatsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Statistiken (Zeitraum)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart),
              label: const Text("Detaillierte Statistiken"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- CALENDAR ---
  Widget _buildMonthlyCalendar() {
    final monthFormat = DateFormat('MMMM yyyy', 'de_DE');
    final displayMonth = monthFormat.format(_currentMonth);

    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    final tasksByDay = <int, List<Task>>{};
    for (int i = 1; i <= daysInMonth; i++) {
      tasksByDay[i] = [];
    }

    // Populate tasks per day
    for (var t in allTasks) {
      final c = t.creationDate;
      final d = t.dueDate;
      if (c == null || d == null) continue;
      DateTime start = DateTime.parse(c).toLocal();
      DateTime end = DateTime.parse(d).toLocal();

      final startOfMonth = firstDayOfMonth;
      final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month, daysInMonth, 23, 59);

      if (end.isBefore(startOfMonth) || start.isAfter(endOfMonth)) continue;
      if (start.isBefore(startOfMonth)) start = startOfMonth;
      if (end.isAfter(endOfMonth)) end = endOfMonth;

      DateTime cur = DateTime(start.year, start.month, start.day);
      while (!cur.isAfter(end)) {
        if (cur.month == _currentMonth.month) {
          final dayNum = cur.day;
          tasksByDay[dayNum]?.add(t);
        }
        cur = cur.add(const Duration(days: 1));
      }
    }

    final firstWeekday = firstDayOfMonth.weekday; 
    final offset = (firstWeekday - 1) % 7;

    final dayTiles = <Widget>[];
    for (int i = 0; i < offset; i++) {
      dayTiles.add(const SizedBox.shrink());
    }
    for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
      final tasksToday = tasksByDay[dayNum] ?? [];
      dayTiles.add(_buildCalendarDay(dayNum, tasksToday));
    }

    final weekdaysDe = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Month nav
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  displayMonth,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Weekday headings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdaysDe.map((w) {
                return Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth / 7) - 8;
                return Wrap(
                  children: List.generate(dayTiles.length, (index) {
                    return SizedBox(
                      width: tileWidth,
                      child: dayTiles[index],
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(int dayNum, List<Task> tasksToday) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$dayNum", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tasksToday.map((t) {
                  return InkWell(
                    onTap: () => _showTaskDialog(t),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _getTaskColor(t.title).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        t.title,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // OPEN TASKS
  Widget _buildOffeneAufgabenListe(List<Task> offene) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Offene Aufgaben", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (offene.isEmpty)
              const Text("Keine offenen Aufgaben.")
            else
              ...offene.map((task) {
                final cardColor = _getTaskColor(task.title).withOpacity(0.15);

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    // Make task title bold black
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                          InkWell(
                            onTap: () => _goToUserStats(task.assignedTo!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (task.assignedTo == "Otter") ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (task.assignedTo == "Otter") ? Colors.black : Colors.grey,
                                ),
                              ),
                              child: Text(
                                task.assignedTo!,
                                style: TextStyle(
                                  color: (task.assignedTo == "Otter") ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Make "Erstellt am:" label bold black, date normal
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.creationDate != null)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Erstellt am: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: Utils.formatDateTime(task.creationDate),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        if (task.dueDate != null)
                          _buildTimeRemainingBar(task.creationDate, task.dueDate),
                      ],
                    ),
                    // "Fertigstellen" with a green background
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50), // green color
                      ),
                      onPressed: () => _finishTask(task),
                      child: const Text("Fertigstellen"),
                    ),
                  ),
                );
              }).toList()
          ],
        ),
      ),
    );
  }

  // COMPLETED TASKS
  Widget _buildErledigteAufgaben(List<Task> erledigte) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Erledigte Aufgaben", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedCompletedRange,
                  items: _statRanges.map((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: Text(s),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCompletedRange = val ?? "Letzte 7 Tage";
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (erledigte.isEmpty)
              const Text("Keine erledigten Aufgaben.")
            else
              ...erledigte.map((task) {
                final color = _getTaskColor(task.title).withOpacity(0.15);

                final created = DateTime.tryParse(task.creationDate ?? "");
                final done = DateTime.tryParse(task.completedOn ?? "");
                Duration? diff;
                if (created != null && done != null) {
                  diff = done.difference(created);
                }
                String timeTaken = "";
                if (diff != null) {
                  final days = diff.inDays;
                  final hours = diff.inHours % 24;
                  final minutes = diff.inMinutes % 60;
                  final parts = <String>[];
                  if (days > 0) parts.add("${days}d");
                  if (hours > 0) parts.add("${hours}h");
                  if (minutes > 0) parts.add("${minutes}m");
                  timeTaken = parts.isEmpty ? "0m" : parts.join(" ");
                }

                return Card(
                  color: color,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    // Make title bold black
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                          InkWell(
                            onTap: () => _goToUserStats(task.assignedTo!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (task.assignedTo == "Otter") ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (task.assignedTo == "Otter") ? Colors.black : Colors.grey,
                                ),
                              ),
                              child: Text(
                                task.assignedTo!,
                                style: TextStyle(
                                  color: (task.assignedTo == "Otter") ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.creationDate != null)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Erstellt am: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: Utils.formatDateTime(task.creationDate),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        if (task.completedOn != null)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Erledigt am: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: Utils.formatDateTime(task.completedOn),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        // Dauer label bold, value normal
                        if (timeTaken.isNotEmpty)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Dauer: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: timeTaken,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _showWieselStats = !_showWieselStats),
              child: Row(
                children: [
                  const Text("Wiesel Stats", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(_showWieselStats ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_showWieselStats) _buildUserStats("Wiesel"),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showOtterStats = !_showOtterStats),
              child: Row(
                children: [
                  const Text("Otter Stats", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(_showOtterStats ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_showOtterStats) _buildUserStats("Otter"),
          ],
        ),
      ),
    );
  }

  // Simple expansions for user stats placeholders
  Widget _buildUserStats(String username) {
    final totalDone = 10;
    final avgTime = "8h";
    final favoriteTask = "Küche";
    final favoriteCount = 6;
    final leastFavTask = "kochen";
    final leastFavCount = 2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Benutzer: $username", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Insgesamt erledigt: $totalDone"),
          Text("Durchschnittliche Zeit pro Aufgabe: $avgTime"),
          Text("Lieblingsaufgabe: $favoriteTask ($favoriteCount Mal)"),
          Text("Unbeliebteste Aufgabe: $leastFavTask ($leastFavCount Mal)"),
        ],
      ),
    );
  }

  // Time progress bar
  Widget _buildTimeRemainingBar(String? creationStr, String? dueStr) {
    if (creationStr == null || dueStr == null) return const SizedBox();
    final now = DateTime.now();
    final created = DateTime.parse(creationStr).toLocal();
    final due = DateTime.parse(dueStr).toLocal();
    final total = due.difference(created).inSeconds;
    final current = now.difference(created).inSeconds;
    if (total <= 0) return const SizedBox();

    final remaining = total - current;
    final percent = (current / total).clamp(0.0, 1.0);
    final hrs = (remaining / 3600).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Verbleibend ca. $hrs Std."),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: Colors.grey.shade300,
          color: const Color(0xFFFF5C00),
          minHeight: 6,
        ),
      ],
    );
  }

  // Decide color based on task title
  Color _getTaskColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains("wäsche")) return const Color(0xFF653993);
    if (lower.contains("küche")) return const Color(0xFF431307);
    if (lower.contains("kochen")) return const Color(0xFF9B1C31);
    return Colors.grey;
  }
}
