// lib/screens/dashboard_screen.dart, do not remove this line!

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/screens/personal_stats_screen.dart';
import 'package:flutter_tasktracker/screens/stats_screen.dart';
import 'package:flutter_tasktracker/utils.dart';
import 'package:flutter_tasktracker/notification_service.dart'; // Must be implemented separately

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

  // For new task creation
  String _selectedTitle = "Wäsche";
  final List<String> _taskTitles = ["Wäsche", "Küche", "kochen", "Custom"];
  final _customTitleController = TextEditingController();

  int _selectedDuration = 48;
  final List<int> _durations = [12, 24, 48, 72];

  String? _assignedTo;
  final List<String?> _assignments = [null, "Wiesel", "Otter"];

  // Calendar view and current month
  String _calendarView = "Woche";
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // Completed tasks filter
  final List<String> _statRanges = [
    "Letzte 7 Tage",
    "Seit Montag",
    "Letzte 14 Tage",
    "Letzte 30 Tage",
    "Aktueller Monat",
  ];
  String _selectedCompletedRange = "Letzte 7 Tage";

  // Bottom bar index
  int _selectedBottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
    NotificationService.init(); // Initialize local notifications on start
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

  // ================= NOTIFICATIONS =================
  void _scheduleNotifications(Task task, String action) async {
    // This is a demonstration of local notifications usage.
    if (action == "new" && task.assignedTo != null) {
      final body = "Neue Aufgabe '${task.title}' zugewiesen an ${task.assignedTo!}";
      NotificationService.showNotification(
        title: "Neue Aufgabe",
        body: body,
      );
    } else if (action == "completed") {
      final body = "Aufgabe '${task.title}' erledigt von ${task.completedBy}";
      NotificationService.showNotification(
        title: "Aufgabe erledigt",
        body: body,
      );
    } else if (action == "edited") {
      NotificationService.showNotification(
        title: "Aufgabe geändert",
        body: "Die Aufgabe '${task.title}' wurde bearbeitet.",
      );
    } else if (action == "resend") {
      NotificationService.showNotification(
        title: "Benachr. erneut gesendet",
        body: "Aufgabe: ${task.title}",
      );
    }
  }

  // ================= NEW TASK =================
  void _showNewTaskDialog() {
    // Reset fields
    _selectedTitle = "Wäsche";
    _customTitleController.clear();
    _selectedDuration = 48;
    _assignedTo = null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Neue Aufgabe erstellen", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Aufgabe
                Row(
                  children: [
                    const Text("Aufgabe: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedTitle,
                      items: _taskTitles.map((t) {
                        return DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTitle = val ?? "Wäsche");
                      },
                    ),
                  ],
                ),
                if (_selectedTitle == "Custom") ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customTitleController,
                    decoration: const InputDecoration(labelText: "Eigener Taskname"),
                  ),
                ],
                const SizedBox(height: 16),
                // Dauer
                Row(
                  children: [
                    const Text("Dauer (h): ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedDuration,
                      items: _durations.map((d) {
                        return DropdownMenuItem<int>(
                          value: d,
                          child: Text("$d"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedDuration = val ?? 48);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Zuweisen an
                Row(
                  children: [
                    const Text("Zuweisen an: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _assignedTo,
                      items: _assignments.map((p) {
                        final display = p ?? "Niemand";
                        return DropdownMenuItem<String?>(
                          value: p,
                          child: Text(display),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _assignedTo = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Schliessen", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _createTask,
              child: const Text("Erstellen"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createTask() async {
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

      if (newTask.assignedTo != null && newTask.assignedTo!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aufgabe '$title' wurde ${newTask.assignedTo} zugewiesen!")),
        );
        _scheduleNotifications(newTask, "new");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aufgabe '$title' erstellt (niemand zugewiesen).")),
        );
      }
      _customTitleController.clear();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Fehler beim Erstellen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Erstellen.")),
      );
    }
  }

  // ================= FINISH TASK =================
  void _confirmFinishTask(Task task) {
    final assignedTo = task.assignedTo ?? "";
    final isMine = assignedTo.toLowerCase() == widget.currentUser.toLowerCase();
    final titleText = isMine
        ? "Möchtest du diese Aufgabe wirklich fertigstellen?"
        : "Achtung: Diese Aufgabe ist $assignedTo zugewiesen.\nTrotzdem fertigstellen?";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Aufgabe abschließen?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(titleText),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Schliessen", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _finishTask(task);
              },
              child: const Text("Fertig"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishTask(Task task) async {
    try {
      final updated = await ApiService.finishTask(task.id, widget.currentUser);
      await _fetchAllTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${updated.title}' von ${updated.completedBy} erledigt.")),
      );
      _scheduleNotifications(updated, "completed");
    } catch (e) {
      debugPrint("Fehler beim Abschließen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Abschließen.")),
      );
    }
  }

  // ================= EDIT TASK =================
  void _showEditTaskPopup(Task task) {
    final newAssigned = ValueNotifier<String?>(task.assignedTo);
    final newDuration = ValueNotifier<int>(48);
    final newCategory = ValueNotifier<String>(task.title);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Aufgabe bearbeiten", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ReAssign
              Row(
                children: [
                  const Text("Zuweisen an:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: newAssigned,
                    builder: (context, val, _) {
                      return DropdownButton<String?>(
                        value: val,
                        items: _assignments.map((p) {
                          final display = p ?? "Niemand";
                          return DropdownMenuItem<String?>(
                            value: p,
                            child: Text(display),
                          );
                        }).toList(),
                        onChanged: (v) => newAssigned.value = v,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Change deadline
              Row(
                children: [
                  const Text("Neue Dauer:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: newDuration,
                    builder: (context, val, _) {
                      return DropdownButton<int>(
                        value: val,
                        items: [12, 24, 48, 72].map((d) {
                          return DropdownMenuItem<int>(
                            value: d,
                            child: Text("$d Std."),
                          );
                        }).toList(),
                        onChanged: (v) => newDuration.value = v ?? 48,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Change category
              Row(
                children: [
                  const Text("Kategorie:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: newCategory,
                    builder: (context, val, _) {
                      return DropdownButton<String>(
                        value: val,
                        items: ["Wäsche", "Küche", "kochen", "Sonstiges"].map((t) {
                          return DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          );
                        }).toList(),
                        onChanged: (v) => newCategory.value = v ?? task.title,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Abbrechen", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                debugPrint("Task edited => assigned=${newAssigned.value}, dur=${newDuration.value}, cat=${newCategory.value}");
                _scheduleNotifications(task, "edited");
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  // ================= DELETE TASK =================
  void _confirmDeleteTask(Task task) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Aufgabe löschen?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Soll die Aufgabe '${task.title}' wirklich gelöscht werden?"),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Abbrechen", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                debugPrint("Task deleted => ID=${task.id}");
                // TODO: call deleteTask API
              },
              child: const Text("Löschen"),
            ),
          ],
        );
      },
    );
  }

  // ================= RESEND NOTIFICATION =================
  void _resendNotification(Task task) {
    debugPrint("Resending notification => Task ID ${task.id}");
    _scheduleNotifications(task, "resend");
  }

  // ================= SHOW TASK DIALOG =================
  void _showTaskDialog(Task task) {
    final isCompleted = (task.completed == 1);
    final taskColor = _op(_getTaskColor(task.title), 1.0);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  "Aufgabe: ${task.title}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.assignedTo != null && task.assignedTo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Zugewiesen an: ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        TextSpan(
                          text: task.assignedTo!,
                          style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
                if (task.creationDate != null) ...[
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Erstellt am: ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        TextSpan(
                          text: Utils.formatDateTime(task.creationDate),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
                if (task.dueDate != null) ...[
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Fällig bis: ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        TextSpan(
                          text: Utils.formatDateTime(task.dueDate),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (isCompleted) ...[
                  const Text("Status: ABGESCHLOSSEN", style: TextStyle(color: Colors.green)),
                  if (task.completedBy != null)
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Abgeschlossen von: ",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          TextSpan(
                            text: task.completedBy!,
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
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          TextSpan(
                            text: Utils.formatDateTime(task.completedOn),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                ] else
                  const Text("Status: Offen", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Schliessen", style: TextStyle(color: Colors.white)),
            ),
            if (!isCompleted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _confirmFinishTask(task);
                },
                child: const Text("Fertig"),
              ),
          ],
        );
      },
    );
  }

  // ================= CALENDAR =================
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  Widget _buildCalendarSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _calendarButton("Woche"),
        _calendarButton("Zwei Wochen"),
        _calendarButton("Monat"),
      ],
    );
  }

  Widget _calendarButton(String label) {
    final bool selected = (_calendarView == label);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? Colors.blue : Colors.grey,
        ),
        onPressed: () {
          setState(() => _calendarView = label);
        },
        child: Text(label),
      ),
    );
  }

  Widget _buildCalendar() {
    switch (_calendarView) {
      case "Woche":
        return _buildWeekCalendar();
      case "Zwei Wochen":
        return _buildTwoWeekCalendar();
      case "Monat":
      default:
        return _buildMonthlyCalendar();
    }
  }

  Widget _buildWeekCalendar() {
    final now = DateTime.now();
    final weekday = now.weekday; // Monday = 1
    final monday = now.subtract(Duration(days: weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildFixedGrid(days),
    );
  }

  Widget _buildTwoWeekCalendar() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    final days = List.generate(14, (i) => monday.add(Duration(days: i)));

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildFixedGrid(days),
    );
  }

  Widget _buildMonthlyCalendar() {
    final monthFormat = DateFormat('MMMM yyyy', 'de_DE');
    final displayMonth = monthFormat.format(_currentMonth);

    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday
    final offset = (firstWeekday - 1) % 7;
    final tiles = <DateTime?>[];
    for (int i = 0; i < offset; i++) {
      tiles.add(null);
    }
    for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
      tiles.add(DateTime(_currentMonth.year, _currentMonth.month, dayNum));
    }

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      width: double.infinity,
      child: Column(
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                displayMonth,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWeekdayHeadings(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth / 7) - 8;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tiles.map((date) {
                  return SizedBox(
                    width: tileWidth,
                    child: _buildCalendarDay(date),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFixedGrid(List<DateTime> days) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth / 7) - 8;
        return Column(
          children: [
            _buildWeekdayHeadings(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((d) {
                return SizedBox(
                  width: tileWidth,
                  child: _buildCalendarDay(d),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekdayHeadings() {
    final weekdaysDe = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekdaysDe.map((w) {
        return Expanded(
          child: Center(
            child: Text(
              w,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarDay(DateTime? date) {
    if (date == null) {
      return const SizedBox(height: 80);
    }
    final dayNum = date.day;
    final tasksForThisDay = _tasksForDay(date);

    return InkWell(
      onTap: () => _showDayTasksDialog(date, tasksForThisDay),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$dayNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            for (int i = 0; i < tasksForThisDay.length && i < 2; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _op(_getTaskColor(tasksForThisDay[i].title), 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  tasksForThisDay[i].title,
                  style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (tasksForThisDay.length > 2)
              Text(
                "+${tasksForThisDay.length - 2} weitere...",
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayTasksDialog(DateTime date, List<Task> tasks) {
    final dayLabel = DateFormat('EEEE, d.MMMM', 'de_DE').format(date);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Aufgaben am $dayLabel", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tasks.map((t) {
                  return ListTile(
                    title: Text(
                      t.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: (t.assignedTo != null && t.assignedTo!.isNotEmpty)
                        ? Text("Zugewiesen an: ${t.assignedTo!}")
                        : const Text("Niemand zugewiesen"),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showTaskDialog(t);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Schliessen", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  List<Task> _tasksForDay(DateTime date) {
    final theDayStart = DateTime(date.year, date.month, date.day);
    final theDayEnd = theDayStart.add(const Duration(hours: 23, minutes: 59));
    final tasks = <Task>[];
    for (var t in allTasks) {
      if (t.creationDate == null || t.dueDate == null) continue;
      final c = DateTime.parse(t.creationDate!).toLocal();
      final d = DateTime.parse(t.dueDate!).toLocal();
      if (c.isBefore(theDayEnd) && d.isAfter(theDayStart)) {
        tasks.add(t);
      }
    }
    return tasks;
  }

  // ================= OPEN & COMPLETED TASKS =================
  Widget _buildAssignedToYouSection(List<Task> tasks, int count) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Offene Aufgaben, die dir zugewiesen sind: $count",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              const Text("Keine dir zugewiesenen Aufgaben.")
            else
              ...tasks.map((task) {
                final color = _op(_getTaskColor(task.title), 0.1);
                return Card(
                  color: color,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.creationDate != null)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Erstellt am: ",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                TextSpan(
                                  text: Utils.formatDateTime(task.creationDate),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        if (task.dueDate != null) _buildTimeRemainingBar(task.creationDate, task.dueDate),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                      onPressed: () => _confirmFinishTask(task),
                      child: const Text("Fertig"),
                    ),
                    onTap: () => _showTaskDialog(task),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

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
                final cardColor = _op(_getTaskColor(task.title), 0.15);
                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      // Title row + 3-dot menu
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text(
                                task.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                          TextSpan(
                                            text: Utils.formatDateTime(task.creationDate),
                                            style: const TextStyle(color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (task.dueDate != null) _buildTimeRemainingBar(task.creationDate, task.dueDate),
                                ],
                              ),
                              onTap: () => _showTaskDialog(task),
                            ),
                          ),
                          // 3-dot menu for Edit, Delete, Resend Notification
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == "edit") {
                                _showEditTaskPopup(task);
                              } else if (value == "delete") {
                                _confirmDeleteTask(task);
                              } else if (value == "resend") {
                                _resendNotification(task);
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return [
                                const PopupMenuItem<String>(
                                  value: "edit",
                                  child: Text("Bearbeiten"),
                                ),
                                const PopupMenuItem<String>(
                                  value: "delete",
                                  child: Text("Löschen"),
                                ),
                                const PopupMenuItem<String>(
                                  value: "resend",
                                  child: Text("Benachr. erneut senden"),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                      if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                        Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(bottom: 8, right: 8),
                          child: InkWell(
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
                        ),
                      // "Fertig" button
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                            onPressed: () => _confirmFinishTask(task),
                            child: const Text("Fertig"),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildErledigteAufgaben(List<Task> erledigte) {
    final filtered = erledigte; // or apply filter logic based on _selectedCompletedRange

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
                    setState(() => _selectedCompletedRange = val ?? "Letzte 7 Tage");
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              const Text("Keine erledigten Aufgaben.")
            else
              ...filtered.map((task) {
                final color = _op(_getTaskColor(task.title), 0.15);
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
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.creationDate != null)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Erstellt am: ",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                TextSpan(
                                  text: Utils.formatDateTime(task.completedOn),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        if (timeTaken.isNotEmpty)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Dauer: ",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
                    onTap: () => _showTaskDialog(task),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  // ================= TIME BAR =================
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 24,
          child: Stack(
            children: [
              LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey.shade300,
                color: const Color(0xFFFF5C00),
                minHeight: 24,
              ),
              Center(
                child: Text(
                  "Noch ${hrs} Std.",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= BOTTOM BAR =================
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
              if (_selectedBottomIndex != 0) {
                setState(() => _selectedBottomIndex = 0);
              }
            },
          ),
          _buildBottomBarItem(
            index: 1,
            icon: Icons.bar_chart,
            label: "Statistiken",
            onTapOverride: () {
              setState(() => _selectedBottomIndex = 1);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
          _buildBottomBarItem(
            index: 2,
            icon: Icons.person,
            label: "Pers. Stats",
            onTapOverride: () {
              setState(() => _selectedBottomIndex = 2);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonalStatsScreen(username: widget.currentUser),
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
    VoidCallback? onTapOverride,
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

  // ================= NAVIGATION HELPER =================
  void _goToUserStats(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PersonalStatsScreen(username: username)),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final offeneAufgaben = allTasks.where((t) => t.completed == 0).toList();
    final completedTasks = allTasks.where((t) => t.completed == 1).toList();

    // "Assigned to you" tasks:
    final userAssignedOpenTasks = allTasks.where((t) {
      if (t.completed == 1) return false;
      if (t.assignedTo == null) return false;
      return t.assignedTo!.toLowerCase() == widget.currentUser.toLowerCase();
    }).toList();
    final assignedCount = userAssignedOpenTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Willkommen, ${widget.currentUser}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showNewTaskDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAssignedToYouSection(userAssignedOpenTasks, assignedCount),
            const SizedBox(height: 16),
            _buildOffeneAufgabenListe(offeneAufgaben),
            const SizedBox(height: 16),
            _buildCalendarSelector(),
            const SizedBox(height: 16),
            _buildCalendar(),
            const SizedBox(height: 16),
            _buildErledigteAufgaben(completedTasks),
          ],
        ),
      ),
    );
  }

  // ================= HELPER =================
  Color _op(Color base, double fraction) {
    final alpha = (fraction * 255).round().clamp(0, 255);
    return base.withAlpha(alpha);
  }

  Color _getTaskColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains("wäsche")) return const Color(0xFF653993);
    if (lower.contains("küche")) return const Color(0xFF431307);
    if (lower.contains("kochen")) return const Color(0xFF9B1C31);
    return Colors.grey;
  }
}
