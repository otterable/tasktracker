// lib/api_service.dart, do not remove this line!

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_tasktracker/models/task.dart';
import 'package:flutter_tasktracker/models/stats_response.dart';

class ApiService {
  // Update the base URL for production (use HTTPS)
  static const String baseUrl = "https://molentracker.ermine.at";

  /// -----------------------
  ///  PHONE-based OTP login
  /// -----------------------
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

  static Future<String?> verifyOtp(String phone, String otpCode) async {
    debugPrint("[ApiService] POST /api/verify_otp => phone=$phone, code=$otpCode");
    final response = await http.post(
      Uri.parse("$baseUrl/api/verify_otp"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"phone": phone, "otp_code": otpCode}),
    );
    debugPrint("[ApiService] Response code: ${response.statusCode}");
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint("[ApiService] OTP verify success => $data");
      return data["username"] as String?;
    } else {
      debugPrint("[ApiService] verifyOtp failed => ${response.body}");
      return null;
    }
  }

  /// -----------------------
  ///  Tasks Endpoints
  /// -----------------------
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

  static Future<Task> createTask(String title, int durationHours, String? assignedTo) async {
    debugPrint("[ApiService] POST /api/tasks => title=$title, durationHours=$durationHours, assignedTo=$assignedTo");
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

  // CSV / XLSX export URLs
  static String getCsvExportUrl() => "$baseUrl/export_csv";
  static String getXlsxExportUrl() => "$baseUrl/export_xlsx";

  /// -----------------------
  ///  Push Notifications
  /// -----------------------
  /// Register the device token (from FCM) with your server.
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
}
