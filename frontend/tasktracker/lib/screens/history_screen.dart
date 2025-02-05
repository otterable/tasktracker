// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tasktracker/api_service.dart';
import 'package:flutter_tasktracker/models/task.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends StatefulWidget {
  final String currentUser;
  final String selectedGroupId;

  const HistoryScreen({
    Key? key,
    required this.currentUser,
    required this.selectedGroupId,
  }) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Task> historyTasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      debugPrint("[HistoryScreen] Fetching history for group ${widget.selectedGroupId}");
      List<Task> tasks = await ApiService.getTaskHistory(widget.selectedGroupId);
      setState(() {
        historyTasks = tasks;
        isLoading = false;
      });
      debugPrint("[HistoryScreen] Fetched ${tasks.length} archived tasks");
    } catch (e) {
      debugPrint("[HistoryScreen] Error fetching history: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _exportHistoryCsv() async {
    final url = ApiService.getHistoryCsvExportUrl();
    debugPrint("[HistoryScreen] Exporting history CSV: $url");
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      debugPrint("[HistoryScreen] Could not launch CSV export URL");
    }
  }

  Future<void> _exportHistoryXlsx() async {
    final url = ApiService.getHistoryXlsxExportUrl();
    debugPrint("[HistoryScreen] Exporting history XLSX: $url");
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      debugPrint("[HistoryScreen] Could not launch XLSX export URL");
    }
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd.MM.yyyy, HH:mm').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aufgabenverlauf"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportHistoryCsv,
            tooltip: "Export CSV",
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportHistoryXlsx,
            tooltip: "Export XLSX",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : historyTasks.isEmpty
                ? const Center(child: Text("Keine archivierten Aufgaben gefunden."))
                : ListView.builder(
                    itemCount: historyTasks.length,
                    itemBuilder: (context, index) {
                      Task task = historyTasks[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                task.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (task.recurring == true)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.repeat, size: 16, color: Colors.blue),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.creationDate != null && task.creationDate!.isNotEmpty)
                                Text("Erstellt am: ${_formatDate(task.creationDate!)}"),
                              if (task.dueDate != null && task.dueDate!.isNotEmpty)
                                Text("Fällig bis: ${_formatDate(task.dueDate!)}"),
                              if (task.completedOn != null && task.completedOn!.isNotEmpty)
                                Text("Erledigt am: ${_formatDate(task.completedOn!)}"),
                              if (task.recurring == true)
                                // Updated here as well
                                Text("Wiederholt alle ${task.frequencyHours} h", style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
