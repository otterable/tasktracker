// lib/models/stats_response.dart, do not remove this line!

class CompletionCount {
  final String completedBy;
  final int totalCompleted;

  CompletionCount({
    required this.completedBy,
    required this.totalCompleted,
  });

  factory CompletionCount.fromJson(Map<String, dynamic> json) {
    return CompletionCount(
      completedBy: json["completed_by"] ?? "Unknown",
      totalCompleted: json["total_completed"] ?? 0,
    );
  }
}

class StatsResponse {
  final List<CompletionCount> completions;
  final List<Map<String, dynamic>> allTasksRaw;

  StatsResponse({
    required this.completions,
    required this.allTasksRaw,
  });

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    var compsJson = json["completions"] as List;
    var comps = compsJson.map((c) => CompletionCount.fromJson(c)).toList();

    var tasksJson = json["all_tasks"] as List;
    var tasks = tasksJson.map((t) => t as Map<String, dynamic>).toList();

    return StatsResponse(
      completions: comps,
      allTasksRaw: tasks,
    );
  }
}
