import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';

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

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<dynamic> projects = [];
  List<dynamic> _userGroups = [];
  String? _selectedGroupId;
  bool _isLoading = false;

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _fetchUserGroups().then((_) {
      _fetchProjects();
    });
  }

  Future<void> _fetchUserGroups() async {
    try {
      final groups = await ApiService.getUserGroups(widget.currentUser);
      setState(() {
        _userGroups = groups;
        if (groups.isNotEmpty) {
          // Use the first group if none is selected.
          _selectedGroupId ??= groups[0]['id'].toString();
        }
      });
    } catch (e) {
      debugPrint("Error fetching user groups: $e");
    }
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Retrieve all projects from the API (the API may return projects for all groups)
      final allProjects = await ApiService.getProjects(_selectedGroupId!);
      // Filter the projects to include only those whose "groupId" matches the currently selected group.
      final filteredProjects = allProjects.where((project) {
        // Adjust the key "groupId" if your API returns a different key name (e.g. "group_id")
        return project['groupId'].toString() == _selectedGroupId;
      }).toList();

      setState(() {
        projects = filteredProjects;
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

  Future<void> _createProject() async {
    final name = _projectNameController.text.trim();
    final description = _projectDescriptionController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bitte einen Projektnamen eingeben.")),
      );
      return;
    }
    try {
      await ApiService.createProject(name, description, widget.currentUser, _selectedGroupId!);
      _projectNameController.clear();
      _projectDescriptionController.clear();
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

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Projekte"),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Container(
            color: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Gruppe: ",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _userGroups.isEmpty
                      ? Text("Keine Gruppe gefunden", style: TextStyle(color: Colors.white))
                      : DropdownButton<String>(
                          dropdownColor: Colors.black,
                          style: TextStyle(color: Colors.white),
                          value: _selectedGroupId,
                          onChanged: (newValue) {
                            setState(() {
                              _selectedGroupId = newValue;
                            });
                            _fetchProjects();
                          },
                          items: _userGroups.map<DropdownMenuItem<String>>((group) {
                            return DropdownMenuItem<String>(
                              value: group['id'].toString(),
                              child: Text(group['name'], style: TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProjects,
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _projectNameController,
                      decoration: InputDecoration(labelText: "Projektname"),
                    ),
                    TextField(
                      controller: _projectDescriptionController,
                      decoration: InputDecoration(labelText: "Beschreibung"),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _createProject,
                      child: Text("Projekt erstellen"),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : projects.isEmpty
                    ? Center(child: Text("Keine Projekte gefunden."))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              title: Text(project["name"]),
                              subtitle: Text(project["description"] ?? ""),
                              trailing: Icon(Icons.arrow_forward),
                              onTap: () {
                                // Navigate to a detailed project view if needed.
                              },
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
