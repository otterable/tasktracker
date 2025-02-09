import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';

class ProjectsScreen extends StatefulWidget {
  final String currentUser;
  final String groupId;
  final VoidCallback onLogout;

  const ProjectsScreen({
    Key? key,
    required this.currentUser,
    required this.groupId,
    required this.onLogout,
  }) : super(key: key);

  @override
  _ProjectsScreenState createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> projects = [];
  List<dynamic> _userGroups = [];
  String? _selectedGroupId;
  bool _isLoading = false;

  // Controllers for project creation slide-out panel
  bool _showCreateProjectPanel = false;
  late AnimationController _createProjectPanelController;
  late Animation<Offset> _createProjectPanelSlideAnimation;

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _fetchUserGroups().then((_) {
      _fetchProjects();
    });
    _createProjectPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _createProjectPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _createProjectPanelController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _createProjectPanelController.dispose();
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserGroups() async {
    try {
      debugPrint("[ProjectsScreen] Fetching user groups for ${widget.currentUser}");
      final groups = await ApiService.getUserGroups(widget.currentUser);
      setState(() {
        _userGroups = groups;
        if (groups.isNotEmpty) {
          _selectedGroupId ??= groups[0]['id'].toString();
        }
      });
      debugPrint("[ProjectsScreen] Fetched ${_userGroups.length} user groups.");
    } catch (e) {
      debugPrint("Error fetching user groups: $e");
    }
  }

Future<void> _fetchProjects() async {
  setState(() {
    _isLoading = true;
  });
  try {
    debugPrint("[ProjectsScreen] Fetching projects for group $_selectedGroupId");
    final allProjects = await ApiService.getProjects(_selectedGroupId!);
    // Also fetch all tasks for the group
    final allTasks = await ApiService.getAllTasks(_selectedGroupId!);
    // For each project, compute open and finished tasks counts
    final updatedProjects = allProjects.map((proj) {
      final projId = proj['id'] is int
          ? proj['id'] as int
          : int.tryParse(proj['id'].toString());
      int openCount = 0;
      int finishedCount = 0;
      for (var task in allTasks) {
        // Convert task's project_id to int for safe comparison
        final taskProjId = task.toJson()['project_id'] != null
            ? int.tryParse(task.toJson()['project_id'].toString())
            : null;
        if (taskProjId != null && taskProjId == projId) {
          if (task.completed == 0)
            openCount++;
          else
            finishedCount++;
        }
      }
      proj['open_tasks_count'] = openCount;
      proj['finished_tasks_count'] = finishedCount;
      return proj;
    }).toList();
    debugPrint("[ProjectsScreen] After processing, ${updatedProjects.length} projects remain.");
    setState(() {
      projects = updatedProjects;
    });
  } catch (e) {
    debugPrint("Error fetching projects: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Fehler beim Laden der Projekte.")),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}


  void _openCreateProjectPanel() {
    setState(() {
      _showCreateProjectPanel = true;
    });
    _createProjectPanelController.forward();
  }

  Future<void> _submitCreateProject(String name, String description) async {
    if (name.trim().isEmpty) return;
    try {
      await ApiService.createProject(
          name.trim(), description.trim(), widget.currentUser, _selectedGroupId!);
      _projectNameController.clear();
      _projectDescriptionController.clear();
      _createProjectPanelController.reverse().then((_) {
        setState(() {
          _showCreateProjectPanel = false;
        });
      });
      _fetchProjects();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Projekt '$name' erstellt.")),
      );
    } catch (e) {
      debugPrint("Error creating project: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler beim Erstellen des Projekts.")),
      );
    }
  }

  Widget _buildProjectCard(dynamic project) {
    // Use the computed counts for open and finished tasks.
    final String projectName = project["name"] ?? "";
    final String description = project["description"] ?? "";
    final int openTasks = project["open_tasks_count"] ?? 0;
    final int finishedTasks = project["finished_tasks_count"] ?? 0;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          projectName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16),
                const SizedBox(width: 4),
                Text(
                  "Offen: $openTasks",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline, size: 16),
                const SizedBox(width: 4),
                Text(
                  "Erledigt: $finishedTasks",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          // Navigate to a detailed project view if needed.
        },
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
            icon: const Icon(Icons.add),
            onPressed: _openCreateProjectPanel,
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
                  child: _userGroups.isEmpty
                      ? const Text("Keine Gruppe gefunden",
                          style: TextStyle(color: Colors.white))
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: Colors.black,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            value: _selectedGroupId,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white),
                            items: _userGroups.map<DropdownMenuItem<String>>((group) {
                              String displayText = group['name'];
                              return DropdownMenuItem<String>(
                                value: group['id'].toString(),
                                child: Text(displayText,
                                    style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedGroupId = newValue;
                              });
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
        selectedIndex: 1,
        currentUser: widget.currentUser,
        currentGroupId: _selectedGroupId ?? '',
        onLogout: widget.onLogout,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchProjects,
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (projects.isEmpty)
                  const Center(child: Text("Keine Projekte gefunden."))
                else
                  ...projects.map((project) => _buildProjectCard(project)).toList(),
              ],
            ),
          ),
          if (_showCreateProjectPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _createProjectPanelSlideAnimation,
                child: _buildCreateProjectPanel(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateProjectPanel() {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Projekt erstellen",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _projectNameController,
              decoration: const InputDecoration(
                labelText: "Projektname",
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _projectDescriptionController,
              decoration: const InputDecoration(
                labelText: "Beschreibung",
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _createProjectPanelController.reverse().then((_) {
                      setState(() {
                        _showCreateProjectPanel = false;
                      });
                    });
                  },
                  child: const Text("Abbrechen"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _submitCreateProject(_projectNameController.text,
                        _projectDescriptionController.text);
                  },
                  child: const Text("Erstellen"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
