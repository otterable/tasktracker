// lib\screens\group_management_screen.dart, don't remove this line!
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final String currentUser;

  const GroupManagementScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _GroupManagementScreenState createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  List<dynamic> groups = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Assume the backend endpoint returns groups created by the current user
      final result = await ApiService.getUserGroups(widget.currentUser);
      setState(() {
        groups = result;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Gruppen: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _createGroup() async {
    TextEditingController groupNameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Gruppe erstellen"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(labelText: "Gruppenname"),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Beschreibung"),
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
              final name = groupNameController.text.trim();
              final description = descriptionController.text.trim();
              if (name.isEmpty) return;
              final result = await ApiService.createGroup(name, description, widget.currentUser);
              if (result != null) {
                Navigator.of(ctx).pop();
                _loadGroups();
              }
            },
            child: const Text("Erstellen"),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteUser(String groupId) async {
    // Fetch all users to invite (for simplicity, using a fixed list here)
    List<String> allUsers = await Future.value(["UserA", "UserB", "UserC"]);
    String? selectedUser;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Benutzer einladen"),
        content: DropdownButton<String>(
          value: selectedUser,
          hint: const Text("Benutzer auswählen"),
          items: allUsers.map((user) => DropdownMenuItem(value: user, child: Text(user))).toList(),
          onChanged: (val) {
            setState(() {
              selectedUser = val;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              if (selectedUser != null) {
                final result = await ApiService.inviteUserToGroup(groupId, selectedUser!);
                if (result != null) {
                  Navigator.of(ctx).pop();
                  _loadGroups();
                }
              }
            },
            child: const Text("Einladen"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserRole(String groupId, String username, String role) async {
    final result = await ApiService.updateUserRoleInGroup(groupId, username, role);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rolle aktualisiert")));
    }
  }

  Widget _buildGroupTile(dynamic group) {
    return Card(
      child: ListTile(
        title: Text(group['name']),
        subtitle: Text(group['description'] ?? ""),
        trailing: IconButton(
          icon: const Icon(Icons.group_add),
          onPressed: () {
            _inviteUser(group['id'].toString());
          },
        ),
        onTap: () {
          // Navigate to a detailed view of group members.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GroupMembersScreen(groupId: group['id'].toString(), groupName: group['name'])),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gruppenverwaltung"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGroups,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ElevatedButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.add),
                    label: const Text("Gruppe erstellen"),
                  ),
                  const SizedBox(height: 16),
                  const Text("Deine Gruppen:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  ...groups.map((group) => _buildGroupTile(group)).toList(),
                ],
              ),
            ),
    );
  }
}

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupMembersScreen({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  @override
  _GroupMembersScreenState createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<dynamic> members = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Assume a backend endpoint that returns group members.
      final response = await ApiService.getGroupMembers(widget.groupId);
      setState(() {
        members = response;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Gruppenmitglieder: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _changeRole(String username, String newRole) async {
    await ApiService.updateUserRoleInGroup(widget.groupId, username, newRole);
    _loadMembers();
  }

  Widget _buildMemberTile(dynamic member) {
    return ListTile(
      title: Text(member['username']),
      subtitle: Text("Rolle: ${member['role']}"),
      trailing: DropdownButton<String>(
        value: member['role'],
        items: ["user", "editor", "admin"]
            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
            .toList(),
        onChanged: (val) {
          if (val != null) {
            _changeRole(member['username'], val);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mitglieder: ${widget.groupName}"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMembers,
              child: ListView(
                children: members.map((m) => _buildMemberTile(m)).toList(),
              ),
            ),
    );
  }
}
