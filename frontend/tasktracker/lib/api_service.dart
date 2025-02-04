import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/models/stats_response.dart';

class ApiService {
  static const String baseUrl = "https://molentracker.ermine.at";

  /// PHONE-based OTP login and registration
  static Future<bool> requestOtp(String phone) async {
    debugPrint("[ApiService] POST /api/request_otp => phone=$phone");
    final response = await http.post(
      Uri.parse("$baseUrl/api/request_otp"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"phone": phone}),
    );
    debugPrint("[ApiService] Response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      debugPrint("[ApiService] OTP requested successfully");
      return true;
    } else {
      debugPrint("[ApiService] requestOtp failed => ${response.body}");
      return false;
    }
  }

  /// Updated verifyOtp to return the full JSON response.
  static Future<Map<String, dynamic>?> verifyOtp(String phone, String otpCode) async {
    debugPrint("[ApiService] POST /api/verify_otp => phone=$phone, code=$otpCode");
    final response = await http.post(
      Uri.parse("$baseUrl/api/verify_otp"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"phone": phone, "otp_code": otpCode}),
    );
    debugPrint("[ApiService] Response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint("[ApiService] OTP verify response: $data");
      return data;
    } else {
      debugPrint("[ApiService] verifyOtp failed => ${response.body}");
      return null;
    }
  }

  // Register a new user
  static Future<Map<String, dynamic>?> registerUser(String phone, String username) async {
    debugPrint("[ApiService] POST /api/register => phone=$phone, username=$username");
    final response = await http.post(
      Uri.parse("$baseUrl/api/register"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"phone": phone, "username": username}),
    );
    debugPrint("[ApiService] Response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint("[ApiService] Registration successful: $data");
      return data;
    } else {
      debugPrint("[ApiService] registerUser failed => ${response.body}");
      return null;
    }
  }

  /// -----------------------
  ///  Tasks Endpoints (filtered by active group)
  /// -----------------------
  static Future<List<Task>> getAllTasks(String groupId) async {
    // Expect the backend to filter tasks by group_id
    debugPrint("[ApiService] GET /api/tasks?group_id=$groupId ...");
    final response = await http.get(Uri.parse("$baseUrl/api/tasks?group_id=$groupId"));
    debugPrint("[ApiService] response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      return list.map((jsonItem) => Task.fromJson(jsonItem)).toList();
    } else {
      debugPrint("[ApiService] getAllTasks failed => ${response.body}");
      throw Exception("Failed to load tasks");
    }
  }

  static Future<Task> createTask(String title, int durationHours, String? assignedTo, String groupId,
      {bool recurring = false, int frequencyHours = 24, bool alwaysAssigned = true}) async {
    debugPrint("[ApiService] POST /api/tasks => title=$title, group_id=$groupId, durationHours=$durationHours, assignedTo=$assignedTo, recurring=$recurring");
    final bodyData = {
      "title": title,
      "duration_hours": durationHours,
      "assigned_to": assignedTo,
      "group_id": groupId,
      "recurring": recurring,
      "frequency_hours": recurring ? frequencyHours : null,
      "always_assigned": recurring ? alwaysAssigned : null,
    };
    final response = await http.post(
      Uri.parse("$baseUrl/api/tasks"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return Task.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] createTask failed => ${response.body}");
      throw Exception("Failed to create task");
    }
  }

  static Future<Task> createRecurringTask(String title, int durationHours, String? assignedTo, String groupId,
      int frequencyHours, bool alwaysAssigned) async {
    debugPrint("[ApiService] POST /api/tasks/recurring => title=$title, group_id=$groupId, durationHours=$durationHours, assignedTo=$assignedTo, frequencyHours=$frequencyHours, alwaysAssigned=$alwaysAssigned");
    final bodyData = {
      "title": title,
      "duration_hours": durationHours,
      "assigned_to": assignedTo,
      "group_id": groupId,
      "frequency_hours": frequencyHours,
      "always_assigned": alwaysAssigned,
    };
    final response = await http.post(
      Uri.parse("$baseUrl/api/tasks/recurring"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return Task.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] createRecurringTask failed => ${response.body}");
      throw Exception("Failed to create recurring task");
    }
  }

  static Future<Task> joinTask(int id, String username) async {
    debugPrint("[ApiService] POST /api/tasks/$id/join => username=$username");
    final response = await http.post(
      Uri.parse("$baseUrl/api/tasks/$id/join"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"username": username}),
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Task.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] joinTask failed => ${response.body}");
      throw Exception("Failed to join task");
    }
  }

  static Future<Task> convertTaskToRecurring(int id, int frequencyHours, bool alwaysAssigned) async {
    debugPrint("[ApiService] POST /api/tasks/$id/convert_to_recurring => frequencyHours=$frequencyHours, alwaysAssigned=$alwaysAssigned");
    final response = await http.post(
      Uri.parse("$baseUrl/api/tasks/$id/convert_to_recurring"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"frequency_hours": frequencyHours, "always_assigned": alwaysAssigned}),
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Task.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] convertTaskToRecurring failed => ${response.body}");
      throw Exception("Failed to convert task to recurring");
    }
  }

  static Future<Task> finishTask(int id, String finisher) async {
    debugPrint("[ApiService] POST /api/tasks/$id/finish => finisher=$finisher");
    final response = await http.post(
      Uri.parse("$baseUrl/api/tasks/$id/finish"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"username": finisher}),
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Task.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] finishTask failed => ${response.body}");
      throw Exception("Failed to finish task");
    }
  }

  static Future<void> deleteTask(int id) async {
    debugPrint("[ApiService] DELETE /api/tasks/$id");
    final response = await http.delete(Uri.parse("$baseUrl/api/tasks/$id"));
    if (response.statusCode != 200) {
      debugPrint("[ApiService] deleteTask failed => ${response.body}");
      throw Exception("Failed to delete task");
    }
  }

  static Future<StatsResponse> getStats(String groupId) async {
    debugPrint("[ApiService] GET /api/stats?group_id=$groupId ...");
    final response = await http.get(Uri.parse("$baseUrl/api/stats?group_id=$groupId"));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return StatsResponse.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] getStats failed => ${response.body}");
      throw Exception("Failed to load stats");
    }
  }

  static Future<bool> getHeartbeat() async {
    final url = Uri.parse("$baseUrl/api/heartbeat");
    debugPrint("[ApiService] GET /api/heartbeat => $url");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["status"] == "ok";
    }
    return false;
  }

  // CSV / XLSX export URLs for tasks
  static String getCsvExportUrl() => "$baseUrl/export_csv";
  static String getXlsxExportUrl() => "$baseUrl/export_xlsx";

  /// -----------------------
  ///  Projects Endpoints (with group filtering)
  /// -----------------------
  static Future<List<dynamic>> getProjects(String groupId) async {
    debugPrint("[ApiService] GET /api/projects?group_id=$groupId ...");
    final response = await http.get(Uri.parse("$baseUrl/api/projects?group_id=$groupId"));
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      debugPrint("[ApiService] getProjects returned ${list.length} projects");
      return list;
    } else {
      debugPrint("[ApiService] getProjects failed => ${response.body}");
      throw Exception("Failed to load projects");
    }
  }

  static Future<dynamic> createProject(String name, String description, String createdBy, String groupId) async {
    debugPrint("[ApiService] POST /api/projects => name=$name, createdBy=$createdBy, group_id=$groupId");
    final bodyData = {
      "name": name,
      "description": description,
      "created_by": createdBy,
      "group_id": groupId,
    };
    final response = await http.post(
      Uri.parse("$baseUrl/api/projects"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return jsonData;
    } else {
      debugPrint("[ApiService] createProject failed => ${response.body}");
      throw Exception("Failed to create project");
    }
  }

  static Future<dynamic> createProjectTodo(int projectId, String title, String description, String? dueDate, int points, String groupId) async {
    debugPrint("[ApiService] POST /api/projects/$projectId/todos => title=$title, dueDate=$dueDate, points=$points, group_id=$groupId");
    final bodyData = {
      "title": title,
      "description": description,
      "due_date": dueDate,
      "points": points,
      "group_id": groupId,
    };
    final response = await http.post(
      Uri.parse("$baseUrl/api/projects/$projectId/todos"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return jsonData;
    } else {
      debugPrint("[ApiService] createProjectTodo failed => ${response.body}");
      throw Exception("Failed to create project todo");
    }
  }

  static Future<dynamic> convertProjectTodo(int projectId, int todoId, String assignedTo, int durationHours, int points) async {
    debugPrint("[ApiService] POST /api/projects/$projectId/todos/$todoId/convert => assignedTo=$assignedTo, durationHours=$durationHours, points=$points");
    final bodyData = {
      "assigned_to": assignedTo,
      "duration_hours": durationHours,
      "points": points,
    };
    final response = await http.post(
      Uri.parse("$baseUrl/api/projects/$projectId/todos/$todoId/convert"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return jsonData;
    } else {
      debugPrint("[ApiService] convertProjectTodo failed => ${response.body}");
      throw Exception("Failed to convert project todo");
    }
  }

  static String getProjectsCsvExportUrl() => "$baseUrl/api/projects/export_csv";
  static String getProjectsXlsxExportUrl() => "$baseUrl/api/projects/export_xlsx";

  /// -----------------------
  ///  Group & Permission Endpoints
  /// -----------------------

  // Get groups that the current user belongs to.
  static Future<List<dynamic>> getUserGroups(String username) async {
    debugPrint("[ApiService] GET /api/users/$username/groups");
    final response = await http.get(Uri.parse("$baseUrl/api/users/$username/groups"));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      debugPrint("[ApiService] getUserGroups failed => ${response.body}");
      throw Exception("Failed to load user groups");
    }
  }

  // Create a new group; the creator is automatically the group admin.
  static Future<Map<String, dynamic>?> createGroup(String groupName, String description, String creatorUsername) async {
    debugPrint("[ApiService] POST /api/groups => groupName=$groupName, creator=$creatorUsername");
    final bodyData = {
      "name": groupName,
      "description": description,
      "creator": creatorUsername,
    };
    final response = await http.post(
      Uri.parse("$baseUrl/api/groups"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      debugPrint("[ApiService] createGroup failed => ${response.body}");
      return null;
    }
  }

  // Invite a user to a group.
  static Future<Map<String, dynamic>?> inviteUserToGroup(String groupId, String inviteeUsername) async {
    debugPrint("[ApiService] POST /api/groups/$groupId/invite => invitee=$inviteeUsername");
    final bodyData = {"invitee": inviteeUsername};
    final response = await http.post(
      Uri.parse("$baseUrl/api/groups/$groupId/invite"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("[ApiService] inviteUserToGroup failed => ${response.body}");
      return null;
    }
  }

  // Update a user’s role in a group (e.g. user, editor, admin)
  static Future<Map<String, dynamic>?> updateUserRoleInGroup(String groupId, String username, String role) async {
    debugPrint("[ApiService] PUT /api/groups/$groupId/users/$username => role=$role");
    final bodyData = {"role": role};
    final response = await http.put(
      Uri.parse("$baseUrl/api/groups/$groupId/users/$username"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("[ApiService] updateUserRoleInGroup failed => ${response.body}");
      return null;
    }
  }

  // Export groups (with activities, projects, SOPs) for backup
  static Future<Map<String, dynamic>?> exportGroups(String username) async {
    debugPrint("[ApiService] GET /api/groups/export?username=$username");
    final response = await http.get(Uri.parse("$baseUrl/api/groups/export?username=$username"));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("[ApiService] exportGroups failed => ${response.body}");
      return null;
    }
  }

  // Import groups data (for backup restoration)
  static Future<Map<String, dynamic>?> importGroups(Map<String, dynamic> data) async {
    debugPrint("[ApiService] POST /api/groups/import");
    final response = await http.post(
      Uri.parse("$baseUrl/api/groups/import"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("[ApiService] importGroups failed => ${response.body}");
      return null;
    }
  }

  /// -----------------------
  ///  Push Notifications
  /// -----------------------
  static Future<void> sendDeviceTokenToServer(String token, String username) async {
    debugPrint("[ApiService] sendDeviceTokenToServer => token=$token, username=$username");
    final bodyData = {"token": token, "username": username};
    final response = await http.post(
      Uri.parse("$baseUrl/api/register_token"),
      headers: {"Content-Type": "application/json"},
      body: json.encode(bodyData),
    );
    debugPrint("[ApiService] register_token response code: ${response.statusCode}");
  }

  // NEW: editTask method to update the task title.
  static Future<Task> editTask(int id, String newTitle) async {
    debugPrint("[ApiService] PUT /api/tasks/$id => newTitle=$newTitle");
    final response = await http.put(
      Uri.parse("$baseUrl/api/tasks/$id"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"title": newTitle}),
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Task.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] editTask failed => ${response.body}");
      throw Exception("Failed to edit task");
    }
  }

  // Additional endpoints for SOPs
  static Future<List<dynamic>> getSops() async {
    debugPrint("[ApiService] GET /api/sops");
    final response = await http.get(Uri.parse("$baseUrl/api/sops"));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      debugPrint("[ApiService] getSops failed => ${response.body}");
      throw Exception("Failed to load SOPs");
    }
  }

  static Future<Map<String, dynamic>?> agreeToSop(int sopId, String sopVersion) async {
    debugPrint("[ApiService] POST /api/sop_agreement => sop_id=$sopId, sop_version=$sopVersion");
    final response = await http.post(
      Uri.parse("$baseUrl/api/sop_agreement"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"sop_id": sopId, "sop_version": sopVersion}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("[ApiService] agreeToSop failed => ${response.body}");
      return null;
    }
  }
}
