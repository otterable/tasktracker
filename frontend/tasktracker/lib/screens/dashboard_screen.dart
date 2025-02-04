// lib/screens/dashboard_screen.dart, do not remove this line!

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/screens/personal_stats_screen.dart';
import 'package:flutter_tasktracker/screens/stats_screen.dart';
import 'package:flutter_tasktracker/utils.dart';
import 'package:flutter_tasktracker/notification_service.dart'; // Must be implemented separately
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart'; // Using your custom bottom bar

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

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // Regular tasks and projects
  List<Task> allTasks = [];
  List<dynamic> projects = [];

  // For new task creation (shared with recurring tasks)
  String _selectedTitle = "Wäsche";
  final List<String> _taskTitles = ["Wäsche", "Küche", "kochen", "Custom"];
  final _customTitleController = TextEditingController();

  int _selectedDuration = 48;
  final List<int> _durations = [12, 24, 48, 72];

  String? _assignedTo;
  final List<String?> _assignments = [null, "Wiesel", "Otter"];

  // Additional fields for recurring tasks in the new task panel:
  // (Task type: Normal or Wiederkehrend)
  String _selectedTaskType = "Normal";
  final List<String> _taskTypes = ["Normal", "Wiederkehrend"];
  // For recurring tasks: frequency options (the default is 24 hours)
  String _selectedFrequencyOption = "24 Stunden";
  final List<String> _frequencyOptions = [
    "24 Stunden",
    "48 Stunden",
    "72 Stunden",
    "1 Woche",
    "2 Wochen",
    "1 Monat",
    "Custom"
  ];
  final _customFrequencyController = TextEditingController();
  // Option for recurring tasks: always use same assignee or let it be unassigned
  bool _alwaysAssigned = true;
  // Option to leave task unassigned (for both types)
  bool _unassignedTask = false;

  // Calendar view and filter settings
  String _calendarView = "Woche";
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final List<String> _statRanges = [
    "Letzte 7 Tage",
    "Seit Montag",
    "Letzte 14 Tage",
    "Letzte 30 Tage",
    "Aktueller Monat",
  ];
  String _selectedCompletedRange = "Letzte 7 Tage";

  // Bottom bar index (Dashboard is index 0)
  int _selectedBottomIndex = 0;

  // Slide-out panels:
  // (1) Task detail panel
  Task? _selectedTask;
  late AnimationController _detailPanelController;
  late Animation<Offset> _detailPanelSlideAnimation;

  // (2) New task creation panel
  bool _showNewTaskPanel = false;
  late AnimationController _newTaskPanelController;
  late Animation<Offset> _newTaskPanelSlideAnimation;

  // (3) Convert task to recurring panel
  bool _showConvertRecurringPanel = false;
  Task? _taskToConvert;
  late AnimationController _convertRecurringPanelController;
  late Animation<Offset> _convertRecurringPanelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
    _fetchProjects();
    NotificationService.init(); // Initialize local notifications on start

    // Task detail panel controller
    _detailPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _detailPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _detailPanelController,
        curve: Curves.easeInOut,
      ),
    );
    _detailPanelController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _selectedTask = null;
        });
      }
    });

    // New task panel controller
    _newTaskPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _newTaskPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _newTaskPanelController,
        curve: Curves.easeInOut,
      ),
    );
    _newTaskPanelController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _showNewTaskPanel = false;
        });
      }
    });

    // Convert recurring panel controller
    _convertRecurringPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _convertRecurringPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _convertRecurringPanelController,
        curve: Curves.easeInOut,
      ),
    );
    _convertRecurringPanelController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _showConvertRecurringPanel = false;
          _taskToConvert = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _detailPanelController.dispose();
    _newTaskPanelController.dispose();
    _convertRecurringPanelController.dispose();
    _customTitleController.dispose();
    _customFrequencyController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllTasks() async {
    try {
      final tasks = await ApiService.getAllTasks();
      debugPrint("[Dashboard] Fetched ${tasks.length} tasks");
      setState(() {
        allTasks = tasks;
      });
    } catch (e) {
      debugPrint("[Dashboard] Fehler beim Laden der Aufgaben: $e");
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final proj = await ApiService.getProjects();
      debugPrint("[Dashboard] Fetched ${proj.length} projects");
      setState(() {
        projects = proj;
      });
    } catch (e) {
      debugPrint("[Dashboard] Fehler beim Laden der Projekte: $e");
      setState(() {
        projects = [];
      });
    }
  }

  // ================= NOTIFICATIONS =================
  void _scheduleNotifications(Task task, String action) async {
    if (action == "new" && task.assignedTo != null) {
      final body =
          "Neue Aufgabe '${task.title}' zugewiesen an ${task.assignedTo!}";
      NotificationService.showNotification(title: "Neue Aufgabe", body: body);
    } else if (action == "completed") {
      final body =
          "Aufgabe '${task.title}' erledigt von ${task.completedBy}";
      NotificationService.showNotification(
          title: "Aufgabe erledigt", body: body);
    } else if (action == "edited") {
      NotificationService.showNotification(
          title: "Aufgabe geändert",
          body: "Die Aufgabe '${task.title}' wurde bearbeitet.");
    } else if (action == "resend") {
      NotificationService.showNotification(
          title: "Benachr. erneut gesendet", body: "Aufgabe: ${task.title}");
    }
  }

  // ================= NEW TASK CREATION SLIDE-OUT PANEL =================
  void _openNewTaskPanel() {
    setState(() {
      _selectedTitle = "Wäsche";
      _customTitleController.clear();
      _selectedDuration = 48;
      _assignedTo = null;
      _selectedTaskType = "Normal";
      _selectedFrequencyOption = "24 Stunden";
      _customFrequencyController.clear();
      _alwaysAssigned = true;
      _unassignedTask = false;
      _showNewTaskPanel = true;
    });
    _newTaskPanelController.forward();
  }

  Widget _buildNewTaskPanel() {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill-shaped colored bar (using the primary color)
              Center(
                child: Container(
                  width: 60,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Neue Aufgabe erstellen",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Task type dropdown (Normal vs Wiederkehrend)
              Row(
                children: [
                  const Text("Aufgabentyp: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedTaskType,
                    items: _taskTypes
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedTaskType = val ?? "Normal";
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Task title
              Row(
                children: [
                  const Text("Aufgabe: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedTitle,
                    items: _taskTitles
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedTitle = val ?? "Wäsche";
                      });
                    },
                  ),
                ],
              ),
              if (_selectedTitle == "Custom") ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customTitleController,
                  decoration:
                      const InputDecoration(labelText: "Eigener Taskname"),
                ),
              ],
              const SizedBox(height: 8),
              // For Normal tasks: duration dropdown
              if (_selectedTaskType == "Normal") ...[
                Row(
                  children: [
                    const Text("Dauer (h): ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedDuration,
                      items: _durations
                          .map((d) => DropdownMenuItem<int>(
                              value: d, child: Text("$d")))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDuration = val ?? 48;
                        });
                      },
                    ),
                  ],
                ),
              ],
              // For recurring tasks: frequency dropdown and expiration duration
              if (_selectedTaskType == "Wiederkehrend") ...[
                Row(
                  children: [
                    const Text("Häufigkeit: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedFrequencyOption,
                      items: _frequencyOptions
                          .map((option) => DropdownMenuItem(
                              value: option, child: Text(option)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedFrequencyOption = val ?? "24 Stunden";
                        });
                      },
                    ),
                  ],
                ),
                if (_selectedFrequencyOption == "Custom") ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customFrequencyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Eigene Stundenanzahl"),
                  ),
                ],
                Row(
                  children: [
                    const Text("Ablaufdauer (h): ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedDuration,
                      items: _durations
                          .map((d) => DropdownMenuItem<int>(
                              value: d, child: Text("$d")))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDuration = val ?? 48;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _alwaysAssigned,
                      onChanged: (val) {
                        setState(() {
                          _alwaysAssigned = val ?? true;
                        });
                      },
                    ),
                    const Text("Immer derselbe Bearbeiter"),
                  ],
                ),
              ],
              // Option to leave the task unassigned (joinable)
              Row(
                children: [
                  Checkbox(
                    value: _unassignedTask,
                    onChanged: (val) {
                      setState(() {
                        _unassignedTask = val ?? false;
                      });
                    },
                  ),
                  const Text("Keine Zuweisung (Join-Task)"),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62728),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _newTaskPanelController.reverse();
                    },
                    child: const Text("Schliessen",
                        style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _createNewTask,
                    child: const Text("Erstellen",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createNewTask() async {
    String title;
    if (_selectedTitle == "Custom") {
      title = _customTitleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bitte einen eigenen Tasknamen eingeben.")));
        return;
      }
    } else {
      title = _selectedTitle;
    }

    try {
      Task newTask;
      if (_selectedTaskType == "Normal") {
        newTask = await ApiService.createTask(
            title, _selectedDuration, _unassignedTask ? null : _assignedTo);
      } else {
        // For recurring tasks, we call a new API method.
        int frequencyHours = 24;
        if (_selectedFrequencyOption == "Custom") {
          frequencyHours =
              int.tryParse(_customFrequencyController.text.trim()) ?? 24;
        } else {
          if (_selectedFrequencyOption.contains("24"))
            frequencyHours = 24;
          else if (_selectedFrequencyOption.contains("48"))
            frequencyHours = 48;
          else if (_selectedFrequencyOption.contains("72"))
            frequencyHours = 72;
          else if (_selectedFrequencyOption.contains("1 Woche"))
            frequencyHours = 24 * 7;
          else if (_selectedFrequencyOption.contains("2 Wochen"))
            frequencyHours = 24 * 14;
          else if (_selectedFrequencyOption.contains("1 Monat"))
            frequencyHours = 24 * 30;
        }
        newTask = await ApiService.createRecurringTask(
          title,
          _selectedDuration,
          _unassignedTask ? null : _assignedTo,
          frequencyHours,
          _alwaysAssigned,
        );
      }
      await _fetchAllTasks();
      if (newTask.assignedTo != null && newTask.assignedTo!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Aufgabe '$title' wurde ${newTask.assignedTo} zugewiesen!")));
        _scheduleNotifications(newTask, "new");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Aufgabe '$title' erstellt (niemand zugewiesen).")));
      }
      _newTaskPanelController.reverse();
    } catch (e) {
      debugPrint("Fehler beim Erstellen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fehler beim Erstellen.")));
    }
  }

  // ================= JOIN TASK (for unassigned tasks) =================
  Future<void> _joinTask(Task task) async {
    try {
      // Call an API endpoint to join a task (assign it to the current user)
      Task updatedTask = await ApiService.joinTask(task.id, widget.currentUser);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Aufgabe '${task.title}' wurde dir zugewiesen.")));
    } catch (e) {
      debugPrint("Fehler beim Beitreten zur Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fehler beim Beitreten zur Aufgabe.")));
    }
  }

  // ================= CONVERT TASK TO RECURRING (SLIDE-OUT PANEL) =================
  void _openConvertRecurringPanel(Task task) {
    setState(() {
      _taskToConvert = task;
      _selectedFrequencyOption = "24 Stunden";
      _customFrequencyController.clear();
      _alwaysAssigned = true;
    });
    _convertRecurringPanelController.forward();
  }

  Widget _buildConvertRecurringPanel() {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill-shaped colored bar
              Center(
                child: Container(
                  width: 60,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("In wiederkehrende Aufgabe umwandeln",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("Häufigkeit: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedFrequencyOption,
                    items: _frequencyOptions
                        .map((option) => DropdownMenuItem(
                            value: option, child: Text(option)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedFrequencyOption = val ?? "24 Stunden";
                      });
                    },
                  ),
                ],
              ),
              if (_selectedFrequencyOption == "Custom") ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customFrequencyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Eigene Stundenanzahl"),
                ),
              ],
              Row(
                children: [
                  Checkbox(
                    value: _alwaysAssigned,
                    onChanged: (val) {
                      setState(() {
                        _alwaysAssigned = val ?? true;
                      });
                    },
                  ),
                  const Text("Immer derselbe Bearbeiter"),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62728),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _convertRecurringPanelController.reverse();
                    },
                    child: const Text("Abbrechen",
                        style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _convertTaskToRecurring,
                    child: const Text("Umwandeln",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _convertTaskToRecurring() async {
    if (_taskToConvert == null) return;
    int frequencyHours = 24;
    if (_selectedFrequencyOption == "Custom") {
      frequencyHours =
          int.tryParse(_customFrequencyController.text.trim()) ?? 24;
    } else {
      if (_selectedFrequencyOption.contains("24"))
        frequencyHours = 24;
      else if (_selectedFrequencyOption.contains("48"))
        frequencyHours = 48;
      else if (_selectedFrequencyOption.contains("72"))
        frequencyHours = 72;
      else if (_selectedFrequencyOption.contains("1 Woche"))
        frequencyHours = 24 * 7;
      else if (_selectedFrequencyOption.contains("2 Wochen"))
        frequencyHours = 24 * 14;
      else if (_selectedFrequencyOption.contains("1 Monat"))
        frequencyHours = 24 * 30;
    }
    try {
      Task convertedTask = await ApiService.convertTaskToRecurring(
          _taskToConvert!.id, frequencyHours, _alwaysAssigned);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Aufgabe '${_taskToConvert!.title}' wurde in eine wiederkehrende Aufgabe umgewandelt.")));
      _convertRecurringPanelController.reverse();
    } catch (e) {
      debugPrint("Fehler bei der Umwandlung in wiederkehrende Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fehler bei der Umwandlung.")));
    }
  }

  // ================= SLIDE-OUT TASK DETAIL PANEL =================
  Widget _buildTaskDetailPanel(Task task) {
    final isCompleted = task.completed == 1;
    final taskColor = _op(_getTaskColor(task.title), 1.0);
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // dynamic height based on content
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pill-shaped colored bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 80,
                height: 8,
                decoration: BoxDecoration(
                  color: taskColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with title and close icon.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _detailPanelController.reverse();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                              text: "Zugewiesen an: ",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          TextSpan(
                              text: task.assignedTo!,
                              style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.blue)),
                        ],
                      ),
                    ),
                  if (task.creationDate != null && task.creationDate!.isNotEmpty)
                    ...[
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text: "Erstellt am: ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            TextSpan(
                                text: Utils.formatDateTime(task.creationDate),
                                style: const TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ],
                  if (task.dueDate != null && task.dueDate!.isNotEmpty)
                    ...[
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text: "Fällig bis: ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            TextSpan(
                                text: Utils.formatDateTime(task.dueDate),
                                style: const TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CountdownProgressBar(
                          start: DateTime.tryParse(task.creationDate ?? "")?.toLocal() ??
                              DateTime.now(),
                          end: DateTime.tryParse(task.dueDate ?? "")?.toLocal() ??
                              DateTime.now(),
                          isCompleted: isCompleted,
                          completedOn: (task.completedOn != null &&
                                  task.completedOn!.isNotEmpty)
                              ? DateTime.tryParse(task.completedOn!)?.toLocal()
                              : null,
                        ),
                      ),
                      if (!isCompleted) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 24,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, 24),
                              textStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              _confirmFinishTask(task);
                            },
                            child: const Text("Fertig"),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // If task is unassigned, show join button
                  if (task.assignedTo == null || task.assignedTo!.isEmpty)
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          _joinTask(task);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Join Task",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- Calendar and other sections --------------------
  Widget _buildCalendarViewMenu() {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          setState(() {
            _calendarView = value;
          });
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: "Woche", child: Text("Woche")),
          const PopupMenuItem(value: "Zwei Wochen", child: Text("Zwei Wochen")),
          const PopupMenuItem(value: "Monat", child: Text("Monat")),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 0),
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
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: _buildFixedGrid(days),
    );
  }

  Widget _buildMonthlyCalendar() {
    final monthFormat = DateFormat('MMMM yyyy', 'de_DE');
    final displayMonth = monthFormat.format(_currentMonth);
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                displayMonth,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  _buildCalendarViewMenu(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 0),
          _buildWeekdayHeadings(),
          const SizedBox(height: 0),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth / 7;
              return Wrap(
                spacing: 0,
                runSpacing: 0,
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
        final tileWidth = constraints.maxWidth / 7;
        return Column(
          children: [
            _buildWeekdayHeadings(),
            const SizedBox(height: 0),
            Wrap(
              spacing: 0,
              runSpacing: 0,
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
      children: weekdaysDe
          .map((w) => Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ))
          .toList(),
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
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$dayNum",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tasksForThisDay
                      .map((t) => Text(
                            t.title,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black),
                            overflow: TextOverflow.ellipsis,
                          ))
                      .toList(),
                ),
              ),
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
          title: Text("Aufgaben am $dayLabel",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tasks
                    .map((t) => ListTile(
                          title: Text(t.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: const Text(""),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            // Open slide-out detail panel.
                            setState(() {
                              _selectedTask = t;
                            });
                            _detailPanelController.forward();
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62728),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Schliessen",
                  style: TextStyle(color: Colors.white)),
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
      if (t.creationDate == null ||
          t.creationDate!.isEmpty ||
          t.dueDate == null ||
          t.dueDate!.isEmpty) {
        debugPrint(
            "Skipping task '${t.title}' due to invalid dates: creationDate=${t.creationDate}, dueDate=${t.dueDate}");
        continue;
      }
      try {
        final c = DateTime.parse(t.creationDate!).toLocal();
        final d = DateTime.parse(t.dueDate!).toLocal();
        if (c.isBefore(theDayEnd) && d.isAfter(theDayStart)) {
          tasks.add(t);
        }
      } catch (e) {
        debugPrint(
            "Error parsing dates for task '${t.title}': creationDate=${t.creationDate}, dueDate=${t.dueDate} with error: $e");
      }
    }
    return tasks;
  }

  // -------------------- TASK CARD WIDGET (with special marking for unassigned and conversion option) ----------------
  Widget _buildTaskCard(Task task, {bool isCompleted = false, bool hideAssigned = false}) {
    final cardColor = _op(_getTaskColor(task.title), 0.15);

    // Top bar: shows assigned username if available.
    Widget topBar = Container();
    if (!hideAssigned && task.assignedTo != null && task.assignedTo!.isNotEmpty) {
      topBar = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: _getTaskColor(task.title),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8), topRight: Radius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(task.assignedTo!,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert,
                  color: Colors.white, size: 16),
              onSelected: (value) {
                if (value == "edit") {
                  _showEditTaskPopup(task);
                } else if (value == "delete") {
                  _confirmDeleteTask(task);
                } else if (value == "resend") {
                  _resendNotification(task);
                } else if (value == "convert_recurring") {
                  _openConvertRecurringPanel(task);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: "edit", child: Text("Bearbeiten")),
                const PopupMenuItem(value: "delete", child: Text("Löschen")),
                const PopupMenuItem(value: "resend", child: Text("Benachr. erneut senden")),
                const PopupMenuItem(value: "convert_recurring", child: Text("Als wiederkehrend umwandeln")),
              ],
            ),
          ],
        ),
      );
    }

    // Build subtitle texts.
    List<Widget> subtitleWidgets = [];
    if (task.creationDate != null && task.creationDate!.isNotEmpty) {
      subtitleWidgets.add(RichText(
        text: TextSpan(
          children: [
            const TextSpan(
                text: "Erstellt am: ",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
            TextSpan(
                text: Utils.formatDateTime(task.creationDate),
                style: const TextStyle(color: Colors.black)),
          ],
        ),
      ));
    }
    if (isCompleted && task.completedOn != null && task.completedOn!.isNotEmpty) {
      subtitleWidgets.add(const SizedBox(height: 4));
      subtitleWidgets.add(RichText(
        text: TextSpan(
          children: [
            const TextSpan(
                text: "Erledigt am: ",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
            TextSpan(
                text: Utils.formatDateTime(task.completedOn),
                style: const TextStyle(color: Colors.black)),
          ],
        ),
      ));
    }
    final creation = DateTime.tryParse(task.creationDate ?? "");
    final due = DateTime.tryParse(task.dueDate ?? "");
    final completedOn = (task.completedOn != null && task.completedOn!.isNotEmpty)
        ? DateTime.tryParse(task.completedOn!)
        : null;
    Widget progressBar = const SizedBox.shrink();
    if (creation != null && due != null) {
      progressBar = CountdownProgressBar(
        start: creation.toLocal(),
        end: due.toLocal(),
        isCompleted: isCompleted,
        completedOn: completedOn?.toLocal(),
      );
    }

    Widget taskBody = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black)),
          if (subtitleWidgets.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...subtitleWidgets,
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: progressBar),
              if (!isCompleted) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 24),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _confirmFinishTask(task),
                    child: const Text("Fertig"),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return InkWell(
      onTap: () {
        // If the task is unassigned, join it; otherwise open detail panel.
        if (task.assignedTo == null || task.assignedTo!.isEmpty) {
          _joinTask(task);
        } else {
          setState(() {
            _selectedTask = task;
          });
          _detailPanelController.forward();
        }
      },
      child: Card(
        color: cardColor,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hideAssigned &&
                task.assignedTo != null &&
                task.assignedTo!.isNotEmpty)
              topBar,
            taskBody,
          ],
        ),
      ),
    );
  }

  // -------------------- Sections (Offene Aufgaben, Erledigte Aufgaben, Assigned To You, Projects) --------------------
  Widget _buildOffeneAufgabenListe(List<Task> offene) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with badge.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Offene Aufgaben",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(offene.length.toString(),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            if (offene.isEmpty)
              const Text("Keine offenen Aufgaben.")
            else
              ...offene.map((task) => _buildTaskCard(task)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildErledigteAufgaben(List<Task> erledigte) {
    final filtered = erledigte;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Erledigte Aufgaben",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(filtered.length.toString(),
                      style: const TextStyle(color: Colors.white)),
                ),
                DropdownButton<String>(
                  value: _selectedCompletedRange,
                  items: _statRanges
                      .map((s) =>
                          DropdownMenuItem<String>(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCompletedRange = val ?? "Letzte 7 Tage";
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              const Text("Keine erledigten Aufgaben.")
            else
              ...filtered
                  .map((task) =>
                      _buildTaskCard(task, isCompleted: true))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedToYouSection(List<Task> tasks, int count) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Meine offene Aufgaben",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(count.toString(),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            if (tasks.isEmpty)
              const Text("Keine dir zugewiesenen Aufgaben.")
            else
              ...tasks
                  .map((task) => _buildTaskCard(task, hideAssigned: true))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Projekte",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              const Text("Keine Projekte gefunden.")
            else
              ...projects
                  .map((project) => _buildProjectCard(project))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    List<dynamic> todos = project["todos"] ?? [];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Text(
          project["name"],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(project["description"] ?? ""),
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              final bool isTask = (todo["is_task"] == 1);
              return Card(
                color: isTask ? Colors.green[50] : Colors.orange[50],
                margin: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 8),
                child: ListTile(
                  title: Text(todo["title"]),
                  subtitle: Text(todo["description"] ?? ""),
                  trailing: isTask
                      ? (todo["assigned_to"] != null
                          ? Chip(
                              label: Text(todo["assigned_to"]),
                              backgroundColor: Colors.blue[100],
                            )
                          : null)
                      : ElevatedButton(
                          onPressed: () {
                            _showConvertTodoDialog(
                                project["id"], todo["id"]);
                          },
                          child: const Text("Umwandeln"),
                        ),
                  onTap: () {
                    debugPrint(
                        "[Dashboard] Todo/Aufgabe angeklickt: ${todo["title"]}");
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(todo["title"]),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "Beschreibung: ${todo["description"] ?? "Keine"}"),
                            Text(
                                "Erstellt am: ${todo["creation_date"]}"),
                            if (todo["due_date"] != null)
                              Text("Fällig bis: ${todo["due_date"]}"),
                            if (isTask && todo["assigned_to"] != null)
                              Text("Zugewiesen an: ${todo["assigned_to"]}"),
                            if (isTask) Text("Punkte: ${todo["points"]}"),
                          ],
                        ),
                        actionsAlignment: MainAxisAlignment.center,
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(),
                            child: const Text("Schliessen"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                _showCreateTodoDialog(project["id"]);
              },
              icon: const Icon(Icons.add),
              label: const Text("Neuen Todo hinzufügen"),
            ),
          )
        ],
      ),
    );
  }

  void _showCreateTodoDialog(int projectId) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descController = TextEditingController();
    TextEditingController dueController = TextEditingController();
    TextEditingController pointsController =
        TextEditingController(text: "0");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Neuen Todo hinzufügen"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration:
                    const InputDecoration(labelText: "Todo Titel"),
              ),
              TextField(
                controller: descController,
                decoration:
                    const InputDecoration(labelText: "Beschreibung"),
              ),
              TextField(
                controller: dueController,
                decoration: const InputDecoration(
                    labelText: "Fälligkeitsdatum (ISO)"),
              ),
              TextField(
                controller: pointsController,
                decoration:
                    const InputDecoration(labelText: "Punkte"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[Dashboard] Todo-Erstellung abgebrochen");
              Navigator.of(context).pop();
            },
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descController.text.trim();
              final dueDate = dueController.text.trim();
              final points =
                  int.tryParse(pointsController.text.trim()) ?? 0;
              if (title.isEmpty) {
                debugPrint("[Dashboard] Todo Titel leer");
                return;
              }
              try {
                final todo = await ApiService.createProjectTodo(
                    projectId,
                    title,
                    description,
                    dueDate.isEmpty ? null : dueDate,
                    points);
                debugPrint("[Dashboard] Todo erstellt: ${todo}");
                Navigator.of(context).pop();
                _fetchProjects();
              } catch (e) {
                debugPrint("[Dashboard] Fehler bei der Todo-Erstellung: $e");
              }
            },
            child: const Text("Erstellen"),
          ),
        ],
      ),
    );
  }

  void _showConvertTodoDialog(int projectId, int todoId) {
    TextEditingController assignedController = TextEditingController();
    TextEditingController durationController =
        TextEditingController(text: "48");
    TextEditingController pointsController =
        TextEditingController(text: "0");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Todo in Aufgabe umwandeln"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: assignedController,
                decoration: const InputDecoration(
                    labelText: "Zuweisen an (Benutzername)"),
              ),
              TextField(
                controller: durationController,
                decoration:
                    const InputDecoration(labelText: "Dauer in Stunden"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: pointsController,
                decoration:
                    const InputDecoration(labelText: "Punkte"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[Dashboard] Umwandlung abgebrochen");
              Navigator.of(context).pop();
            },
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              final assignedTo = assignedController.text.trim();
              final duration =
                  int.tryParse(durationController.text.trim()) ?? 48;
              final points =
                  int.tryParse(pointsController.text.trim()) ?? 0;
              if (assignedTo.isEmpty) {
                debugPrint("[Dashboard] Kein Benutzer zugewiesen");
                return;
              }
              try {
                final converted = await ApiService.convertProjectTodo(
                    projectId, todoId, assignedTo, duration, points);
                debugPrint("[Dashboard] Todo umgewandelt: ${converted}");
                Navigator.of(context).pop();
                _fetchProjects();
              } catch (e) {
                debugPrint("[Dashboard] Fehler bei der Umwandlung: $e");
              }
            },
            child: const Text("Umwandeln"),
          ),
        ],
      ),
    );
  }

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

  // -------------------- HELPER METHODS --------------------
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

  // -------------------- MISSING METHODS ADDED BELOW --------------------

  void _confirmFinishTask(Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Aufgabe abschließen"),
        content: Text("Möchtest du die Aufgabe '${task.title}' als erledigt markieren?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _finishTask(task);
            },
            child: const Text("Bestätigen"),
          ),
        ],
      ),
    );
  }

  Future<void> _finishTask(Task task) async {
    try {
      // Pass the current user as the finisher.
      final updatedTask = await ApiService.finishTask(task.id, widget.currentUser);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${task.title}' als erledigt markiert.")),
      );
      _scheduleNotifications(updatedTask, "completed");
    } catch (e) {
      debugPrint("Fehler beim Abschließen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Abschließen der Aufgabe.")),
      );
    }
  }

  void _showEditTaskPopup(Task task) {
    final TextEditingController editController = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Aufgabe bearbeiten"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(labelText: "Taskname"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = editController.text.trim();
              if (newTitle.isNotEmpty) {
                try {
                  final updatedTask = await ApiService.editTask(task.id, newTitle);
                  await _fetchAllTasks();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Aufgabe aktualisiert: $newTitle")),
                  );
                } catch (e) {
                  debugPrint("Fehler beim Bearbeiten der Aufgabe: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Fehler beim Bearbeiten der Aufgabe.")),
                  );
                }
              }
              Navigator.of(ctx).pop();
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTask(Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Aufgabe löschen"),
        content: Text("Möchtest du die Aufgabe '${task.title}' wirklich löschen?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteTask(task);
            },
            child: const Text("Löschen", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await ApiService.deleteTask(task.id);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${task.title}' wurde gelöscht.")),
      );
    } catch (e) {
      debugPrint("Fehler beim Löschen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Löschen der Aufgabe.")),
      );
    }
  }

  void _resendNotification(Task task) {
    _scheduleNotifications(task, "resend");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Benachrichtigung für Aufgabe '${task.title}' erneut gesendet.")),
    );
  }
  // -------------------- END OF MISSING METHODS --------------------

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "Dashboard build: currentUser='${widget.currentUser}', tasks=${allTasks.length}, projects=${projects.length}");
    final offeneAufgaben =
        allTasks.where((t) => t.completed == 0).toList();
    final completedTasks =
        allTasks.where((t) => t.completed == 1).toList();
    final userAssignedOpenTasks = allTasks.where((t) {
      if (t.completed == 1) return false;
      if (t.assignedTo == null) return false;
      return t.assignedTo!.toLowerCase() ==
          widget.currentUser.toLowerCase();
    }).toList();
    final assignedCount = userAssignedOpenTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Persönlicher Dashboard: ${widget.currentUser}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openNewTaskPanel,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 0,
        currentUser: widget.currentUser,
        onLogout: widget.onLogout,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAssignedToYouSection(userAssignedOpenTasks, assignedCount),
                const SizedBox(height: 16),
                _buildOffeneAufgabenListe(offeneAufgaben),
                const SizedBox(height: 16),
                _buildCalendarViewMenu(),
                const SizedBox(height: 16),
                Container(
                  width: MediaQuery.of(context).size.width,
                  child: _buildCalendar(),
                ),
                const SizedBox(height: 16),
                _buildErledigteAufgaben(completedTasks),
                const SizedBox(height: 16),
                _buildProjectsSection(),
              ],
            ),
          ),
          // Slide-out detail panel for selected task.
          if (_selectedTask != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _detailPanelSlideAnimation,
                child: _buildTaskDetailPanel(_selectedTask!),
              ),
            ),
          // Slide-out new task creation panel.
          if (_showNewTaskPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _newTaskPanelSlideAnimation,
                child: _buildNewTaskPanel(),
              ),
            ),
          // Slide-out convert recurring panel.
          if (_showConvertRecurringPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _convertRecurringPanelSlideAnimation,
                child: _buildConvertRecurringPanel(),
              ),
            ),
        ],
      ),
    );
  }
}

//
// ================= CountdownProgressBar Widget =================
//
class CountdownProgressBar extends StatefulWidget {
  final DateTime start;
  final DateTime end;
  final DateTime? completedOn;
  final bool isCompleted;

  const CountdownProgressBar({
    Key? key,
    required this.start,
    required this.end,
    this.completedOn,
    required this.isCompleted,
  }) : super(key: key);

  @override
  _CountdownProgressBarState createState() => _CountdownProgressBarState();
}

class _CountdownProgressBarState extends State<CountdownProgressBar> {
  late Timer _timer;
  Duration _durationDiff = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateDuration();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDuration();
    });
  }

  void _updateDuration() {
    setState(() {
      if (widget.isCompleted && widget.completedOn != null) {
        _durationDiff = widget.completedOn!.difference(widget.end);
      } else {
        _durationDiff = widget.end.difference(DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Helper to format a Duration as "X h Y m Z s"
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return "$hours h ${twoDigits(minutes)} m ${twoDigits(seconds)} s";
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.end.difference(widget.start).inSeconds;
    double percent = 0.0;
    if (totalSeconds > 0) {
      if (widget.isCompleted && widget.completedOn != null) {
        percent = 1.0;
      } else {
        final elapsed = DateTime.now().difference(widget.start).inSeconds;
        percent = (elapsed / totalSeconds).clamp(0.0, 1.0);
      }
    }

    String label;
    Color progressColor;
    if (widget.isCompleted && widget.completedOn != null) {
      if (widget.completedOn!.isAfter(widget.end)) {
        final delta = widget.completedOn!.difference(widget.end);
        label = "Erledigt ${_formatDuration(delta)} zu spät";
        progressColor = const Color(0xFFD62728);
      } else {
        final delta = widget.end.difference(widget.completedOn!);
        label = "Erledigt ${_formatDuration(delta)} vor Deadline";
        progressColor = const Color(0xFF2CA02C);
      }
    } else {
      if (DateTime.now().isAfter(widget.end)) {
        final overdue = DateTime.now().difference(widget.end);
        label = "Verspätet ${_formatDuration(overdue)}";
        progressColor = const Color(0xFFD62728);
      } else {
        final remaining = widget.end.difference(DateTime.now());
        label = "Noch ${_formatDuration(remaining)}";
        progressColor = const Color(0xFFFF5C00);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 24,
        child: Stack(
          children: [
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade300,
              color: progressColor,
              minHeight: 24,
            ),
            Center(
              child: Text(
                label,
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
    );
  }
}
