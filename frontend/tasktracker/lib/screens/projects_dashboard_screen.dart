import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/utils.dart';

class ProjectsDashboardScreen extends StatefulWidget {
  final String currentUser;
  final VoidCallback onLogout;
  const ProjectsDashboardScreen({Key? key, required this.currentUser, required this.onLogout}) : super(key: key);

  @override
  State<ProjectsDashboardScreen> createState() => _ProjectsDashboardScreenState();
}

class _ProjectsDashboardScreenState extends State<ProjectsDashboardScreen> {
  bool _loading = false;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _loading = true;
    });
    try {
      final projects = await ApiService.getProjects();
      debugPrint("[ProjectsDashboard] Fetched ${projects.length} projects");
      setState(() {
        _projects = projects;
      });
    } catch (e) {
      debugPrint("[ProjectsDashboard] Error fetching projects: $e");
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Dialog to create a new project.
  void _showCreateProjectDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Neues Projekt erstellen"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Projektname"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Beschreibung"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[ProjectsDashboard] Projekt-Erstellung abgebrochen");
              Navigator.of(context).pop();
            },
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descController.text.trim();
              if (name.isEmpty) {
                debugPrint("[ProjectsDashboard] Projektname leer");
                return;
              }
              try {
                final project = await ApiService.createProject(name, description, widget.currentUser);
                debugPrint("[ProjectsDashboard] Projekt erstellt: ${jsonEncode(project)}");
                Navigator.of(context).pop();
                _fetchProjects();
              } catch (e) {
                debugPrint("[ProjectsDashboard] Fehler bei der Projekterstellung: $e");
              }
            },
            child: const Text("Erstellen"),
          ),
        ],
      ),
    );
  }

  // Dialog to create a new todo for a given project.
  void _showCreateTodoDialog(int projectId) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descController = TextEditingController();
    TextEditingController dueController = TextEditingController();
    TextEditingController pointsController = TextEditingController(text: "0");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Neuen Todo hinzufügen"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Todo Titel"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Beschreibung"),
              ),
              TextField(
                controller: dueController,
                decoration: const InputDecoration(labelText: "Fälligkeitsdatum (ISO)"),
              ),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: "Punkte"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[ProjectsDashboard] Todo-Erstellung abgebrochen");
              Navigator.of(context).pop();
            },
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descController.text.trim();
              final dueDate = dueController.text.trim();
              final points = int.tryParse(pointsController.text.trim()) ?? 0;
              if (title.isEmpty) {
                debugPrint("[ProjectsDashboard] Todo Titel leer");
                return;
              }
              try {
                final todo = await ApiService.createProjectTodo(projectId, title, description, dueDate.isEmpty ? null : dueDate, points);
                debugPrint("[ProjectsDashboard] Todo erstellt: ${jsonEncode(todo)}");
                Navigator.of(context).pop();
                _fetchProjects();
              } catch (e) {
                debugPrint("[ProjectsDashboard] Fehler bei der Todo-Erstellung: $e");
              }
            },
            child: const Text("Erstellen"),
          ),
        ],
      ),
    );
  }

  // Dialog to convert a todo into a full task (aufgabe).
  void _showConvertTodoDialog(int projectId, int todoId) {
    TextEditingController assignedController = TextEditingController();
    TextEditingController durationController = TextEditingController(text: "48");
    TextEditingController pointsController = TextEditingController(text: "0");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Todo in Aufgabe umwandeln"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: assignedController,
                decoration: const InputDecoration(labelText: "Zuweisen an (Benutzername)"),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: "Dauer in Stunden"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: "Punkte"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("[ProjectsDashboard] Umwandlung abgebrochen");
              Navigator.of(context).pop();
            },
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              final assignedTo = assignedController.text.trim();
              final duration = int.tryParse(durationController.text.trim()) ?? 48;
              final points = int.tryParse(pointsController.text.trim()) ?? 0;
              if (assignedTo.isEmpty) {
                debugPrint("[ProjectsDashboard] Kein Benutzer zugewiesen");
                return;
              }
              try {
                final converted = await ApiService.convertProjectTodo(projectId, todoId, assignedTo, duration, points);
                debugPrint("[ProjectsDashboard] Todo umgewandelt: ${jsonEncode(converted)}");
                Navigator.of(context).pop();
                _fetchProjects();
              } catch (e) {
                debugPrint("[ProjectsDashboard] Fehler bei der Umwandlung: $e");
              }
            },
            child: const Text("Umwandeln"),
          ),
        ],
      ),
    );
  }

  // Build a card widget for a single project.
  Widget _buildProjectCard(Map<String, dynamic> project) {
    List<dynamic> todos = project["todos"] ?? [];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
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
              final bool isTask = todo["is_task"] == 1;
              return Card(
                color: isTask ? Colors.green[50] : Colors.orange[50],
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                            _showConvertTodoDialog(project["id"], todo["id"]);
                          },
                          child: const Text("Umwandeln"),
                        ),
                  onTap: () {
                    debugPrint("[ProjectsDashboard] Todo/Aufgabe angeklickt: ${todo["title"]}");
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(todo["title"]),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Beschreibung: ${todo["description"] ?? "Keine"}"),
                            Text("Erstellt am: ${todo["creation_date"]}"),
                            if (todo["due_date"] != null)
                              Text("Fällig bis: ${todo["due_date"]}"),
                            if (isTask && todo["assigned_to"] != null)
                              Text("Zugewiesen an: ${todo["assigned_to"]}"),
                            if (isTask)
                              Text("Punkte: ${todo["points"]}"),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Schließen"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Projekte"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              debugPrint("[ProjectsDashboard] Refresh pressed");
              _fetchProjects();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProjects,
              child: ListView.builder(
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  return _buildProjectCard(_projects[index]);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateProjectDialog,
        child: const Icon(Icons.add),
        tooltip: "Neues Projekt erstellen",
      ),
    );
  }
}
