// lib/screens/group_management_screen.dart, don't remove this line!
import 'package:flutter/material.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/widgets/custom_bottom_bar.dart';

class GroupManagementScreen extends StatefulWidget {
  final String currentUser;

  const GroupManagementScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  _GroupManagementScreenState createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> groups = [];
  bool isLoading = false;

  // For create group slide-out panel
  bool _showCreateGroupPanel = false;
  late AnimationController _createGroupPanelController;
  late Animation<Offset> _createGroupPanelSlideAnimation;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _createGroupPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _createGroupPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _createGroupPanelController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _createGroupPanelController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Call the GET endpoint to fetch groups for the current user.
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

  void _openCreateGroupPanel() {
    setState(() {
      _showCreateGroupPanel = true;
    });
    _createGroupPanelController.forward();
  }

  Future<void> _submitCreateGroup(String name, String description) async {
    if (name.trim().isEmpty) return;
    final result = await ApiService.createGroup(
        name.trim(), description.trim(), widget.currentUser);
    if (result != null) {
      _createGroupPanelController.reverse().then((_) {
        setState(() {
          _showCreateGroupPanel = false;
        });
      });
      _loadGroups();
    }
  }

  Future<void> _inviteUser(String groupId) async {
    // For simplicity, using a fixed list of users.
    List<String> allUsers = await Future.value(["UserA", "UserB", "UserC"]);
    String? selectedUser;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Benutzer einladen"),
        content: DropdownButton<String>(
          value: selectedUser,
          hint: const Text("Benutzer auswählen"),
          items: allUsers
              .map((user) =>
                  DropdownMenuItem(value: user, child: Text(user)))
              .toList(),
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
                final result =
                    await ApiService.inviteUserToGroup(groupId, selectedUser!);
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

  Widget _buildGroupTile(dynamic group) {
    return GroupTile(
      group: group,
      inviteUser: (groupId) {
        _inviteUser(groupId);
      },
      onTap: () {
        // Navigate to the group members screen.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupMembersScreen(
              groupId: group['id'].toString(),
              groupName: group['name'],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gruppenverwaltung"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openCreateGroupPanel,
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(
        selectedIndex: 1,
        currentUser: widget.currentUser,
        currentGroupId: "",
        onLogout: () {},
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Text(
                        "Deine Gruppen:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...groups.map((group) => _buildGroupTile(group)).toList(),
                    ],
                  ),
                ),
          if (_showCreateGroupPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _createGroupPanelSlideAnimation,
                child: _buildCreateGroupPanel(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupPanel() {
    TextEditingController groupNameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
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
              "Gruppe erstellen",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: "Gruppenname",
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
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
                    _createGroupPanelController.reverse().then((_) {
                      setState(() {
                        _showCreateGroupPanel = false;
                      });
                    });
                  },
                  child: const Text("Abbrechen"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _submitCreateGroup(
                        groupNameController.text, descriptionController.text);
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

class GroupTile extends StatefulWidget {
  final dynamic group;
  final Function(String groupId) inviteUser;
  final VoidCallback onTap;

  const GroupTile(
      {Key? key,
      required this.group,
      required this.inviteUser,
      required this.onTap})
      : super(key: key);

  @override
  _GroupTileState createState() => _GroupTileState();
}

class _GroupTileState extends State<GroupTile> {
  int membersCount = 0;
  int projectsCount = 0;
  bool isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final String groupId = widget.group['id'].toString();
      final members = await ApiService.getGroupMembers(groupId);
      final projects = await ApiService.getProjects(groupId);
      setState(() {
        membersCount = members.length;
        projectsCount = projects.length;
        isLoadingCounts = false;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Zähler: $e");
      setState(() {
        isLoadingCounts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Invite Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.group['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.group_add, color: Colors.black),
                    onPressed: () {
                      widget.inviteUser(widget.group['id'].toString());
                    },
                  ),
                ],
              ),
              if (widget.group['description'] != null &&
                  widget.group['description'].toString().trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    widget.group['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              isLoadingCounts
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(Icons.group,
                            size: 16, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          "$membersCount Mitglieder",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.work,
                            size: 16, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          "$projectsCount Projekte",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 14),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupMembersScreen(
      {Key? key, required this.groupId, required this.groupName})
      : super(key: key);

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
      // Call the new GET endpoint for group members.
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
