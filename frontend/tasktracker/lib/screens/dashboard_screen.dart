import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/screens/group_management_screen.dart';
import 'package:flutter_tasktracker/screens/history_screen.dart';
import 'package:flutter_tasktracker/utils.dart';
import 'package:flutter_tasktracker/notification_service.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';

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
  // Regular tasks
  List<Task> allTasks = [];

  // For new task creation (shared with recurring tasks)
  String _selectedTitle = "Wäsche";
  final List<String> _taskTitles = ["Wäsche", "Küche", "kochen", "Custom"];
  final _customTitleController = TextEditingController();

  int _selectedDuration = 48;
  final List<int> _durations = [12, 24, 48, 72];

  // For assignment dropdown.
  String? _selectedActivityUser;

  // Additional fields for recurring tasks:
  String _selectedTaskType = "Normal";
  final List<String> _taskTypes = ["Normal", "Wiederkehrend"];
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
  bool _alwaysAssigned = true;
  bool _unassignedTask = false;

  // Group selection
  List<dynamic> _userGroups = [];
  String _selectedGroupId = "default";
  // In the new task panel, the user may choose a different group.
  String? _selectedActivityGroupId;
  List<dynamic> _groupMembers = [];

  // Project selection (for new task creation)
  // Now allow null as a valid project option ("Kein Projekt")
  int? _selectedProjectId;
  List<dynamic> projects = [];

  // Slide-out panels:
  Task? _selectedTask;
  late AnimationController _detailPanelController;
  late Animation<Offset> _detailPanelSlideAnimation;

  bool _showNewTaskPanel = false;
  late AnimationController _newTaskPanelController;
  late Animation<Offset> _newTaskPanelSlideAnimation;

  bool _showConvertRecurringPanel = false;
  Task? _taskToConvert;
  late AnimationController _convertRecurringPanelController;
  late Animation<Offset> _convertRecurringPanelSlideAnimation;

  // Slide-out panels for finishing and joining tasks
  bool _showFinishTaskPanel = false;
  Task? _taskToFinish;
  late AnimationController _finishTaskPanelController;
  late Animation<Offset> _finishTaskPanelSlideAnimation;

  bool _showJoinTaskPanel = false;
  Task? _taskToJoin;
  late AnimationController _joinTaskPanelController;
  late Animation<Offset> _joinTaskPanelSlideAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint("[Dashboard] initState() called for user: ${widget.currentUser}");
    _fetchUserGroups().then((_) {
      _fetchAllTasks();
      _fetchProjects(); // Uses _selectedActivityGroupId if available.
    });
    NotificationService.init();

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

    // Finish task panel controller
    _finishTaskPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _finishTaskPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _finishTaskPanelController,
        curve: Curves.easeInOut,
      ),
    );
    _finishTaskPanelController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _showFinishTaskPanel = false;
          _taskToFinish = null;
        });
      }
    });

    // Join task panel controller
    _joinTaskPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _joinTaskPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _joinTaskPanelController,
        curve: Curves.easeInOut,
      ),
    );
    _joinTaskPanelController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _showJoinTaskPanel = false;
          _taskToJoin = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _detailPanelController.dispose();
    _newTaskPanelController.dispose();
    _convertRecurringPanelController.dispose();
    _finishTaskPanelController.dispose();
    _joinTaskPanelController.dispose();
    _customTitleController.dispose();
    _customFrequencyController.dispose();
    super.dispose();
  }

  // --- Helper Methods ---
  int? _getTaskProjectId(Task task) {
    // Assuming that task.toJson() returns a Map containing a key "project_id"
    final Map<String, dynamic> json = task.toJson();
    return json['project_id'] as int?;
  }

  String _getProjectName(int projectId) {
    final matching = projects.where((proj) => proj['id'] == projectId).toList();
    if (matching.isNotEmpty) {
      return matching.first['name'];
    }
    return "Unassigned";
  }

  // New: Open assign-to-project dialog for tasks with no project assigned.
  void _openAssignProjectPanel(Task task) {
    int? selectedProjectId =
        _getTaskProjectId(task) ?? (projects.isNotEmpty ? projects[0]['id'] as int : null);
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Projekt zuweisen"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Wähle ein Projekt aus:"),
                const SizedBox(height: 12),
                projects.isNotEmpty
                    ? DropdownButton<int?>(
                        value: selectedProjectId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text("Kein Projekt"),
                          ),
                          ...projects.map<DropdownMenuItem<int>>((proj) {
                            return DropdownMenuItem<int>(
                              value: proj['id'] as int,
                              child: Text(proj['name']),
                            );
                          }).toList(),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            selectedProjectId = newValue;
                          });
                        },
                      )
                    : const Text("Keine Projekte verfügbar"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Abbrechen"),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    debugPrint("[Dashboard] Assigning task id=${task.id} to project id=$selectedProjectId");
                    await ApiService.editTask(task.id, task.title, projectId: selectedProjectId);
                    await _fetchAllTasks();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Aufgabe '${task.title}' wurde zu Projekt zugewiesen.")));
                  } catch (e) {
                    debugPrint("[Dashboard] Fehler beim Zuweisen des Projekts: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fehler beim Zuweisen des Projekts.")));
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text("Zuweisen"),
              ),
            ],
          );
        });
      },
    );
  }

  // --- Group fetching ---
  Future<void> _fetchUserGroups() async {
    try {
      debugPrint("[Dashboard] Fetching user groups for ${widget.currentUser}");
      final groups = await ApiService.getUserGroups(widget.currentUser);
      setState(() {
        _userGroups = groups;
        if (groups.isNotEmpty) {
          _selectedGroupId = groups[0]['id'].toString();
          _selectedActivityGroupId = _selectedGroupId;
        }
      });
      debugPrint("[Dashboard] _userGroups: $_userGroups");
    } catch (e) {
      debugPrint("[Dashboard] Error fetching user groups: $e");
    }
  }

  Future<void> _fetchAllTasks() async {
    try {
      debugPrint("[Dashboard] Fetching tasks for group $_selectedGroupId");
      final tasks = await ApiService.getAllTasks(_selectedGroupId);
      debugPrint("[Dashboard] Fetched ${tasks.length} tasks for group $_selectedGroupId");
      setState(() {
        allTasks = tasks;
      });
    } catch (e) {
      debugPrint("[Dashboard] Fehler beim Laden der Aufgaben: $e");
    }
  }

// Updated _fetchProjects: use _selectedActivityGroupId (if available) and parse project_id as int.
Future<void> _fetchProjects() async {
  try {
    final groupForProjects = _selectedActivityGroupId ?? _selectedGroupId;
    debugPrint("[Dashboard] Fetching projects for group $groupForProjects");
    final proj = await ApiService.getProjects(groupForProjects);
    debugPrint("[Dashboard] Fetched ${proj.length} projects for group $groupForProjects");
    setState(() {
      projects = proj;
      // Allow a "no project" option; parse the first project id if available.
      if (projects.isNotEmpty) {
        _selectedProjectId = projects[0]['id'] is int
            ? projects[0]['id'] as int
            : int.tryParse(projects[0]['id'].toString());
      } else {
        _selectedProjectId = null;
      }
    });
  } catch (e) {
    debugPrint("[Dashboard] Fehler beim Laden der Projekte: $e");
    setState(() {
      projects = [];
      _selectedProjectId = null;
    });
  }
}


  // Fetch members of a given group (for the new task assignee dropdown)
  Future<void> _fetchGroupMembers(String groupId) async {
    try {
      debugPrint("[Dashboard] Fetching group members for group $groupId");
      final members = await ApiService.getGroupMembers(groupId);
      setState(() {
        _groupMembers = members;
        if (members.isNotEmpty) {
          _selectedActivityUser = members[0]['username'];
        } else {
          _selectedActivityUser = null;
        }
      });
      debugPrint("[Dashboard] _groupMembers: $_groupMembers");
    } catch (e) {
      debugPrint("[Dashboard] Error fetching group members: $e");
    }
  }

  // ================= NOTIFICATIONS =================
  void _scheduleNotifications(Task task, String action) async {
    debugPrint("[Dashboard] Scheduling notification for task '${task.title}', action=$action");
    if (action == "new" && task.assignedTo != null) {
      final body = "Neue Aufgabe '${task.title}' zugewiesen an ${task.assignedTo!}";
      NotificationService.showNotification(title: "Neue Aufgabe", body: body);
    } else if (action == "completed") {
      final body = "Aufgabe '${task.title}' erledigt von ${task.completedBy}";
      NotificationService.showNotification(title: "Aufgabe erledigt", body: body);
    } else if (action == "edited") {
      NotificationService.showNotification(title: "Aufgabe geändert", body: "Die Aufgabe '${task.title}' wurde bearbeitet.");
    } else if (action == "resend") {
      NotificationService.showNotification(title: "Benachr. erneut gesendet", body: "Aufgabe: ${task.title}");
    }
  }

  // ================= NEW TASK CREATION SLIDE-OUT PANEL =================
  void _openNewTaskPanel() {
    debugPrint("[Dashboard] _openNewTaskPanel() called");
    setState(() {
      _selectedTitle = "Wäsche";
      _customTitleController.clear();
      _selectedDuration = 48;
      _selectedTaskType = "Normal";
      _selectedFrequencyOption = "24 Stunden";
      _customFrequencyController.clear();
      _alwaysAssigned = true;
      _unassignedTask = false;
      _showNewTaskPanel = true;
      _selectedActivityGroupId = _selectedGroupId;
    });
    if (_selectedActivityGroupId != null) {
      _fetchGroupMembers(_selectedActivityGroupId!);
      _fetchProjects();
    }
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
              if (_selectedTaskType == "Wiederkehrend") ...[
                Row(
                  children: [
                    const Text("Häufigkeit: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedFrequencyOption,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
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
                    decoration:
                        const InputDecoration(labelText: "Eigene Stundenanzahl"),
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
              // Group selection row
              Row(
                children: [
                  const Text("Gruppe: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedActivityGroupId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black),
                    items: _userGroups.map<DropdownMenuItem<String>>((group) {
                      String displayText =
                          "${group['name']} (${group['open_task_count']} offene Aufgaben)";
                      return DropdownMenuItem<String>(
                        value: group['id'].toString(),
                        child: Text(
                          displayText,
                          style: const TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      debugPrint("[Dashboard] Activity group changed to: $newValue");
                      setState(() {
                        _selectedActivityGroupId = newValue;
                      });
                      _fetchGroupMembers(newValue!);
                      _fetchProjects().then((_) {
                        if (projects.isNotEmpty) {
                          setState(() {
                            _selectedProjectId = projects[0]['id'] is int
                                ? projects[0]['id'] as int
                                : int.tryParse(projects[0]['id'].toString());
                          });
                        } else {
                          setState(() {
                            _selectedProjectId = null;
                          });
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Project selection row with a default option "Kein Projekt"
              Row(
                children: [
                  const Text("Projekt: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  projects.isNotEmpty
                      ? DropdownButton<int?>(
                          value: _selectedProjectId,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Colors.black),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text("Kein Projekt"),
                            ),
                            ...projects.map<DropdownMenuItem<int>>((proj) {
                              return DropdownMenuItem<int>(
                                value: proj['id'] is int
                                    ? proj['id'] as int
                                    : int.tryParse(proj['id'].toString()),
                                child: Text(proj['name']),
                              );
                            }).toList(),
                          ],
                          onChanged: (newValue) {
                            setState(() {
                              _selectedProjectId = newValue;
                            });
                          },
                        )
                      : const Text("Keine Projekte"),
                ],
              ),
              const SizedBox(height: 8),
              if (!_unassignedTask)
                Row(
                  children: [
                    const Text("Bearbeiter: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _groupMembers.isEmpty
                        ? const Text("Keine Mitglieder gefunden")
                        : DropdownButton<String>(
                            value: _selectedActivityUser,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Colors.black),
                            items: _groupMembers
                                .map((member) => DropdownMenuItem<String>(
                                      value: member['username'],
                                      child: Text(member['username']),
                                    ))
                                .toList(),
                            onChanged: (newUser) {
                              debugPrint("[Dashboard] Assignee changed to: $newUser");
                              setState(() {
                                _selectedActivityUser = newUser;
                              });
                            },
                          ),
                  ],
                ),
              Row(
                children: [
                  Checkbox(
                    value: _unassignedTask,
                    onChanged: (val) {
                      debugPrint("[Dashboard] _unassignedTask changed to: $val");
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
                      debugPrint("[Dashboard] Close new task panel");
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
    debugPrint("[Dashboard] _createNewTask() called");
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
    if (!_unassignedTask && (_selectedActivityUser == null || _selectedActivityUser!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bitte wählen Sie einen Bearbeiter aus.")));
      return;
    }
    final activityGroup = _selectedActivityGroupId ?? _selectedGroupId;
    debugPrint("[Dashboard] Creating task: title=$title, duration=$_selectedDuration, group=$activityGroup, taskType=$_selectedTaskType, project=$_selectedProjectId");
    if (!_unassignedTask)
      debugPrint("[Dashboard] Assignee: $_selectedActivityUser");
    try {
      Task newTask;
      if (_selectedTaskType == "Normal") {
        newTask = await ApiService.createTask(
          title,
          _selectedDuration,
          _unassignedTask ? null : _selectedActivityUser,
          activityGroup,
          projectId: _selectedProjectId,
        );
      } else {
        int frequencyHours = 24;
        if (_selectedFrequencyOption == "Custom") {
          frequencyHours = int.tryParse(_customFrequencyController.text.trim()) ?? 24;
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
          _unassignedTask ? null : _selectedActivityUser,
          activityGroup,
          frequencyHours,
          _alwaysAssigned,
          projectId: _selectedProjectId,
        );
      }
      debugPrint("[Dashboard] New task created successfully: ${newTask.toJson()}");
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
      debugPrint("[Dashboard] Fehler beim Erstellen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fehler beim Erstellen.")));
    }
  }

  // ================= NEW: Slide-out panel for finishing a task =================
  void _openFinishTaskPanel(Task task) {
    setState(() {
      _taskToFinish = task;
      _showFinishTaskPanel = true;
    });
    _finishTaskPanelController.forward();
  }

  Widget _buildFinishTaskPanel() {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text(
              "Aufgabe abschließen",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 16),
            if (_taskToFinish != null)
              Text(
                "Möchtest du die Aufgabe '${_taskToFinish!.title}' als erledigt markieren?",
                style: const TextStyle(color: Colors.black),
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
                    _finishTaskPanelController.reverse();
                  },
                  child: const Text("Abbrechen", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (_taskToFinish != null) {
                      await _finishTask(_taskToFinish!);
                    }
                    _finishTaskPanelController.reverse();
                  },
                  child: const Text("Bestätigen", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finishTask(Task task) async {
    try {
      debugPrint("[Dashboard] Finishing task id=${task.id} by user ${widget.currentUser}");
      await ApiService.finishTask(task.id, widget.currentUser);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${task.title}' wurde als erledigt markiert und archiviert.")),
      );
      _scheduleNotifications(task, "completed");
    } catch (e) {
      debugPrint("[Dashboard] Fehler beim Abschließen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Abschließen der Aufgabe.")),
      );
    }
  }

  // ================= NEW: Slide-out panel for joining a task =================
  void _openJoinTaskPanel(Task task) {
    setState(() {
      _taskToJoin = task;
      _showJoinTaskPanel = true;
    });
    _joinTaskPanelController.forward();
  }

  Widget _buildJoinTaskPanel() {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text(
              "Aufgabe übernehmen",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 16),
            if (_taskToJoin != null)
              Text(
                "Möchtest du die Aufgabe '${_taskToJoin!.title}' übernehmen?",
                style: const TextStyle(color: Colors.black),
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
                    _joinTaskPanelController.reverse();
                  },
                  child: const Text("Abbrechen", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (_taskToJoin != null) {
                      await _performJoinTask(_taskToJoin!);
                    }
                    _joinTaskPanelController.reverse();
                  },
                  child: const Text("Übernehmen", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performJoinTask(Task task) async {
    try {
      await ApiService.joinTask(task.id, widget.currentUser);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aufgabe '${task.title}' wurde dir zugewiesen.")));
      _detailPanelController.reverse();
    } catch (e) {
      debugPrint("[Dashboard] Fehler beim Beitreten zur Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fehler beim Beitreten zur Aufgabe.")));
    }
  }

  // ================= NEW: Methods for converting a task to recurring =================
  void _openConvertRecurringPanel(Task task) {
    debugPrint("[Dashboard] _openConvertRecurringPanel() called for task id=${task.id}");
    setState(() {
      _taskToConvert = task;
      _selectedFrequencyOption = "24 Stunden";
      _customFrequencyController.clear();
      _alwaysAssigned = true;
      _showConvertRecurringPanel = true;
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("Häufigkeit: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedFrequencyOption,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black),
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
                  decoration: const InputDecoration(labelText: "Eigene Stundenanzahl"),
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
                    child: const Text("Abbrechen", style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await _convertTaskToRecurring();
                      _convertRecurringPanelController.reverse();
                    },
                    child: const Text("Umwandeln", style: TextStyle(color: Colors.white)),
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
      frequencyHours = int.tryParse(_customFrequencyController.text.trim()) ?? 24;
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
      debugPrint("[Dashboard] Converting task id=${_taskToConvert!.id} to recurring with frequencyHours=$frequencyHours");
      await ApiService.convertTaskToRecurring(
          _taskToConvert!.id, frequencyHours, _alwaysAssigned);
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Aufgabe '${_taskToConvert!.title}' wurde in eine wiederkehrende Aufgabe umgewandelt.")));
      _scheduleNotifications(_taskToConvert!, "edited");
    } catch (e) {
      debugPrint("[Dashboard] Fehler bei der Umwandlung in wiederkehrende Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fehler bei der Umwandlung.")));
    }
  }

  // ================= SLIDE-OUT TASK DETAIL PANEL =================
  Widget _buildTaskDetailPanel(Task task) {
    final isCompleted = task.completed == 1;
    final taskColor = _op(_getTaskColor(task.title), 1.0);
    String projectName = "";
    final taskProjectId = _getTaskProjectId(task);
    if (taskProjectId != null) {
      projectName = _getProjectName(taskProjectId);
    }
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  // Title row with close button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              task.title,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (task.recurring == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.repeat, size: 20, color: Colors.blue),
                              ),
                          ],
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
                  if (task.recurring == true) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.repeat, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text("Repeats every ${task.frequencyHours} h", style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ],
                  // If no project is assigned, show an "Assign to Project" button.
                  if (taskProjectId == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton(
                        onPressed: () {
                          _openAssignProjectPanel(task);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Projekt zuweisen"),
                      ),
                    )
                  else
                    ...[
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text: "Projekt: ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            TextSpan(
                                text: projectName,
                                style: const TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: CountdownProgressBar(
                        start: DateTime.tryParse(task.creationDate ?? "")?.toLocal() ?? DateTime.now(),
                        end: DateTime.tryParse(task.dueDate ?? "")?.toLocal() ?? DateTime.now(),
                        isCompleted: isCompleted,
                        completedOn: (task.completedOn != null &&
                                task.completedOn!.isNotEmpty)
                            ? DateTime.tryParse(task.completedOn!)?.toLocal()
                            : null,
                      )),
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
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              if (task.assignedTo == null || task.assignedTo!.isEmpty) {
                                _openJoinTaskPanel(task);
                              } else {
                                _openFinishTaskPanel(task);
                              }
                            },
                            child: Text(task.assignedTo == null || task.assignedTo!.isEmpty
                                ? "Übernehmen"
                                : "Fertig"),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- NEW: Moved _buildTaskCard method before it is used ----------------
  Widget _buildTaskCard(Task task, {bool isCompleted = false, bool hideAssigned = false}) {
    final cardColor = _op(_getTaskColor(task.title), 0.15);
    Widget topBar = Container();
    if (!hideAssigned && task.assignedTo != null && task.assignedTo!.isNotEmpty) {
      topBar = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: _getTaskColor(task.title),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(task.assignedTo!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 16),
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
    List<Widget> subtitleWidgets = [];
    if (task.creationDate != null && task.creationDate!.isNotEmpty) {
      subtitleWidgets.add(RichText(
        text: TextSpan(
          children: [
            const TextSpan(
                text: "Erstellt am: ",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            TextSpan(
                text: Utils.formatDateTime(task.creationDate),
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
          Row(
            children: [
              Text(task.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              if (task.recurring == true)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.repeat, size: 16, color: Colors.blue),
                ),
            ],
          ),
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
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (task.assignedTo == null || task.assignedTo!.isEmpty) {
                        _openJoinTaskPanel(task);
                      } else {
                        _openFinishTaskPanel(task);
                      }
                    },
                    child: Text(task.assignedTo == null || task.assignedTo!.isEmpty
                        ? "Übernehmen"
                        : "Fertig"),
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
        setState(() {
          _selectedTask = task;
        });
        _detailPanelController.forward();
      },
      child: Card(
        color: cardColor,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hideAssigned && task.assignedTo != null && task.assignedTo!.isNotEmpty)
              topBar,
            taskBody,
          ],
        ),
      ),
    );
  }

  void _showEditTaskPopup(Task task) {
    final TextEditingController editController =
        TextEditingController(text: task.title);
    // Use the helper method to get the current project id.
    int? selectedProjectId = _getTaskProjectId(task) ?? (projects.isNotEmpty ? projects[0]['id'] as int : null);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Aufgabe bearbeiten"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editController,
                    decoration: const InputDecoration(labelText: "Taskname"),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        "Projekt: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      projects.isNotEmpty
                          ? DropdownButton<int?>(
                              value: selectedProjectId,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text("Kein Projekt"),
                                ),
                                ...projects.map<DropdownMenuItem<int>>((proj) {
                                  return DropdownMenuItem<int>(
                                    value: proj['id'] is int
                                        ? proj['id'] as int
                                        : int.tryParse(proj['id'].toString()),
                                    child: Text(proj['name']),
                                  );
                                }).toList(),
                              ],
                              onChanged: (newValue) {
                                setState(() {
                                  selectedProjectId = newValue;
                                });
                              },
                            )
                          : const Text("Keine Projekte"),
                    ],
                  ),
                ],
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
                        debugPrint(
                            "[Dashboard] Editing task id=${task.id} newTitle=$newTitle, newProjectId=$selectedProjectId");
                        await ApiService.editTask(task.id, newTitle,
                            projectId: selectedProjectId);
                        await _fetchAllTasks();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Aufgabe aktualisiert: $newTitle")),
                        );
                      } catch (e) {
                        debugPrint(
                            "[Dashboard] Fehler beim Bearbeiten der Aufgabe: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Fehler beim Bearbeiten der Aufgabe.")),
                        );
                      }
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text("Speichern"),
                ),
              ],
            );
          },
        );
      },
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
      debugPrint("[Dashboard] Deleting task id=${task.id}");
      await ApiService.deleteTask(task.id);
      debugPrint("[Dashboard] Task deleted and archived: ${task.id}");
      await _fetchAllTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${task.title}' wurde gelöscht und archiviert.")),
      );
    } catch (e) {
      debugPrint("[Dashboard] Fehler beim Löschen der Aufgabe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Löschen der Aufgabe.")),
      );
    }
  }

  void _resendNotification(Task task) {
    debugPrint("[Dashboard] Resending notification for task id=${task.id}");
    _scheduleNotifications(task, "resend");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Benachrichtigung für Aufgabe '${task.title}' erneut gesendet.")),
    );
  }

  // ---------------- Build methods for assigned and open tasks sections ----------------
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildOffeneAufgabenListe(List<Task> offene) {
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
                  const Text("Offene Aufgaben",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  @override
  Widget build(BuildContext context) {
    debugPrint("Dashboard build: currentUser='${widget.currentUser}', tasks=${allTasks.length}");
    final offeneAufgaben = allTasks.where((t) => t.completed == 0).toList();
    final userAssignedOpenTasks = allTasks.where((t) {
      if (t.completed == 1) return false;
      if (t.assignedTo == null) return false;
      return t.assignedTo!.toLowerCase() ==
          widget.currentUser.toLowerCase();
    }).toList();
    final assignedCount = userAssignedOpenTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Tasks"),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupManagementScreen(currentUser: widget.currentUser),
                ),
              ).then((_) async {
                debugPrint(
                    "[Dashboard] Returned from GroupManagementScreen. Refreshing groups...");
                await _fetchUserGroups();
                await _fetchAllTasks();
                await _fetchProjects();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryScreen(
                      currentUser: widget.currentUser,
                      selectedGroupId: _selectedGroupId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openNewTaskPanel,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Container(
            height: 56.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: const BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Gruppe:",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroupId,
                      dropdownColor: Colors.black,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      items: _userGroups.map<DropdownMenuItem<String>>((group) {
                        String displayText =
                            "${group['name']} (${group['open_task_count']} offene Aufgaben)";
                        return DropdownMenuItem<String>(
                          value: group['id'].toString(),
                          child: Text(
                            displayText,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        debugPrint("[Dashboard] Global group changed to: $newValue");
                        setState(() {
                          _selectedGroupId = newValue!;
                        });
                        _fetchAllTasks();
                        _fetchProjects();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 0,
        currentUser: widget.currentUser,
        currentGroupId: _selectedGroupId,
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
              ],
            ),
          ),
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
          if (_showFinishTaskPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _finishTaskPanelSlideAnimation,
                child: _buildFinishTaskPanel(),
              ),
            ),
          if (_showJoinTaskPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _joinTaskPanelSlideAnimation,
                child: _buildJoinTaskPanel(),
              ),
            ),
        ],
      ),
    );
  }

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
      // The widget rebuilds every second. No need to store a duration difference.
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

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
