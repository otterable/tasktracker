// lib/api_service.dart, do not remove this line!

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/models/stats_response.dart';

class ApiService {
  static const String baseUrl = "http://localhost:5444";

  // POST /api/login
  // ADD phone parameter so we can send phone number to the server
  static Future<bool> login(String username, String password, String phone) async {
    debugPrint("[ApiService] POST /api/login => $username:$password, phone=$phone");
    final response = await http.post(
      Uri.parse("$baseUrl/api/login"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "password": password,
        "phone": phone, // <-- send phone here
      }),
    );
    debugPrint("[ApiService] Response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint("[ApiService] Login success => $data");
      return true;
    } else {
      debugPrint("[ApiService] Login failed => ${response.body}");
      return false;
    }
  }

  // GET /api/tasks => returns all tasks
  static Future<List<Task>> getAllTasks() async {
    debugPrint("[ApiService] GET /api/tasks...");
    final response = await http.get(Uri.parse("$baseUrl/api/tasks"));
    debugPrint("[ApiService] response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      return list.map((jsonItem) => Task.fromJson(jsonItem)).toList();
    } else {
      debugPrint("[ApiService] getAllTasks failed => ${response.body}");
      throw Exception("Failed to load tasks");
    }
  }

  // POST /api/tasks => create new task
  static Future<Task> createTask(String title, int durationHours, String? assignedTo) async {
    debugPrint("[ApiService] POST /api/tasks => $title $durationHours $assignedTo");
    final bodyData = {
      "title": title,
      "duration_hours": durationHours,
      "assigned_to": assignedTo,
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

  // POST /api/tasks/<id>/finish => finish a task
  static Future<Task> finishTask(int id, String finisher) async {
    debugPrint("[ApiService] POST /api/tasks/$id/finish => $finisher");
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

  // GET /api/stats => StatsResponse (completions, all_tasks)
  static Future<StatsResponse> getStats() async {
    debugPrint("[ApiService] GET /api/stats...");
    final response = await http.get(Uri.parse("$baseUrl/api/stats"));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return StatsResponse.fromJson(jsonData);
    } else {
      debugPrint("[ApiService] getStats failed => ${response.body}");
      throw Exception("Failed to load stats");
    }
  }

  // GET /api/heartbeat => { "status": "ok" }
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

  // CSV / XLSX
  static String getCsvExportUrl() => "$baseUrl/export_csv";
  static String getXlsxExportUrl() => "$baseUrl/export_xlsx";
}
