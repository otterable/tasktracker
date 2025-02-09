import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';
import 'package:flutter_tasktracker/utils.dart';

class ProjectTasksScreen extends StatefulWidget {
  final String currentUser;
  final String groupId;
  final Map<String, dynamic> project;
  final VoidCallback onLogout;

  const ProjectTasksScreen({
    Key? key,
    required this.currentUser,
    required this.groupId,
    required this.project,
    required this.onLogout,
  }) : super(key: key);

  @override
  _ProjectTasksScreenState createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends State<ProjectTasksScreen>
    with SingleTickerProviderStateMixin {
  List<Task> _projectTasks = [];
  bool _isLoading = false;

  // Slide-out detail panel
  Task? _selectedTask;
  late AnimationController _detailPanelController;
  late Animation<Offset> _detailPanelSlideAnimation;

  // Slide-out finishing panel
  bool _showFinishTaskPanel = false;
  Task? _taskToFinish;
  late AnimationController _finishTaskPanelController;
  late Animation<Offset> _finishTaskPanelSlideAnimation;

  // Slide-out joining panel
  bool _showJoinTaskPanel = false;
  Task? _taskToJoin;
  late AnimationController _joinTaskPanelController;
  late Animation<Offset> _joinTaskPanelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchProjectTasks();

    // Detail panel controller
    _detailPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _detailPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(_detailPanelController);

    // Finish task panel
    _finishTaskPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _finishTaskPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(_finishTaskPanelController);

    // Join task panel
    _joinTaskPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _joinTaskPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(_joinTaskPanelController);
  }

  @override
  void dispose() {
    _detailPanelController.dispose();
    _finishTaskPanelController.dispose();
    _joinTaskPanelController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjectTasks() async {
    setState(() => _isLoading = true);
    try {
      // 1) Load all tasks for the group
      final allGroupTasks = await ApiService.getAllTasks(widget.groupId);

      // 2) Filter tasks for projectId == widget.project['id']
      final projectId = widget.project['id'] is int
          ? widget.project['id'] as int
          : int.tryParse(widget.project['id'].toString());

      final tasksForThisProject = allGroupTasks.where((t) {
        return t.projectId == projectId;
      }).toList();

      setState(() {
        _projectTasks = tasksForThisProject;
      });
    } catch (e) {
      debugPrint("[ProjectTasksScreen] Error fetching tasks: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Laden der Projektaufgaben.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ===================== FINISH TASK =====================
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Aufgabe abschließen",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_taskToFinish != null)
              Text("Möchtest du '${_taskToFinish!.title}' als erledigt markieren?"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _finishTaskPanelController.reverse().then((_) {
                    setState(() {
                      _showFinishTaskPanel = false;
                    });
                  }),
                  child: const Text("Abbrechen"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (_taskToFinish != null) {
                      await _finishTask(_taskToFinish!);
                    }
                    _finishTaskPanelController.reverse().then((_) {
                      setState(() {
                        _showFinishTaskPanel = false;
                      });
                    });
                  },
                  child: const Text("Abschließen"),
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
      await ApiService.finishTask(task.id, widget.currentUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${task.title}' erledigt.")),
      );
      await _fetchProjectTasks();
    } catch (e) {
      debugPrint("[ProjectTasksScreen] Error finishing task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Abschließen der Aufgabe.")),
      );
    }
  }

  // ===================== JOIN TASK =====================
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Aufgabe übernehmen",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_taskToJoin != null)
              Text("Möchtest du '${_taskToJoin!.title}' übernehmen?"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _joinTaskPanelController.reverse().then((_) {
                    setState(() {
                      _showJoinTaskPanel = false;
                    });
                  }),
                  child: const Text("Abbrechen"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (_taskToJoin != null) {
                      await _joinTask(_taskToJoin!);
                    }
                    _joinTaskPanelController.reverse().then((_) {
                      setState(() {
                        _showJoinTaskPanel = false;
                      });
                    });
                  },
                  child: const Text("Übernehmen"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinTask(Task task) async {
    try {
      await ApiService.joinTask(task.id, widget.currentUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aufgabe '${task.title}' wurde dir zugewiesen.")),
      );
      await _fetchProjectTasks();
    } catch (e) {
      debugPrint("[ProjectTasksScreen] Error joining task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fehler beim Übernehmen der Aufgabe.")),
      );
    }
  }

  // ===================== DETAIL PANEL =====================
  void _openTaskDetailPanel(Task task) {
    setState(() {
      _selectedTask = task;
    });
    _detailPanelController.forward();
  }

  Widget _buildTaskDetailPanel(Task task) {
    final isCompleted = (task.completed == 1);
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _detailPanelController.reverse().then((_) {
                        setState(() {
                          _selectedTask = null;
                        });
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                Text("Zugewiesen an: ${task.assignedTo!}"),
              if (task.creationDate != null)
                Text("Erstellt am: ${Utils.formatDateTime(task.creationDate)}"),
              if (task.dueDate != null)
                Text("Fällig bis: ${Utils.formatDateTime(task.dueDate)}"),
              const SizedBox(height: 8),
              // Show a finish / join button if not completed:
              if (!isCompleted)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      if (task.assignedTo == null || task.assignedTo!.isEmpty) {
                        _openJoinTaskPanel(task);
                      } else {
                        _openFinishTaskPanel(task);
                      }
                    },
                    child: Text(task.assignedTo == null || task.assignedTo!.isEmpty
                        ? "Übernehmen"
                        : "Erledigen"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    final isCompleted = (task.completed == 1);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(task.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: isCompleted
            ? const Text("Erledigt")
            : Text("Offen" + (task.assignedTo != null ? " · ${task.assignedTo}" : "")),
        trailing: Icon(isCompleted ? Icons.check : Icons.error_outline),
        onTap: () => _openTaskDetailPanel(task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectTitle = widget.project["name"] ?? "Unbekanntes Projekt";

    return Scaffold(
      appBar: AppBar(
        title: Text("Projekt: $projectTitle"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 1,
        currentUser: widget.currentUser,
        currentGroupId: widget.groupId,
        onLogout: widget.onLogout,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchProjectTasks,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_projectTasks.isEmpty)
                  const Center(child: Text("Keine Aufgaben für dieses Projekt."))
                else
                  ..._projectTasks.map(_buildTaskTile).toList(),
              ],
            ),
          ),
          // Slide-out detail panel
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
          // Slide-out finish task panel
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
          // Slide-out join task panel
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
}
