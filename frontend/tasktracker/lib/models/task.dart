// lib/models/task.dart, do not remove this line!

class Task {
  final int id;
  final String title;
  final String? assignedTo;
  final String? creationDate;
  final String? dueDate;
  final int completed; // 0 or 1
  final String? completedBy;
  final String? completedOn;
  final bool recurring;
  final int? frequencyHours;
  final bool alwaysAssigned;
  final int? projectId; // <-- NEW FIELD

  Task({
    required this.id,
    required this.title,
    this.assignedTo,
    this.creationDate,
    this.dueDate,
    required this.completed,
    this.completedBy,
    this.completedOn,
    required this.recurring,
    this.frequencyHours,
    required this.alwaysAssigned,
    this.projectId, // <-- Add to constructor
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json["id"],
      title: json["title"],
      assignedTo: json["assigned_to"],
      creationDate: json["creation_date"],
      dueDate: json["due_date"],
      completed: json["completed"],
      completedBy: json["completed_by"],
      completedOn: json["completed_on"],
      recurring: json["recurring"] == 1 || json["recurring"] == true,
      frequencyHours: json["frequency_hours"],
      alwaysAssigned: json["always_assigned"] == 1 || json["always_assigned"] == true,
      projectId: json["project_id"], // <-- Parse project_id
    );
  }

  // Add a toJson() method so that you can print the task as JSON.
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "assigned_to": assignedTo,
      "creation_date": creationDate,
      "due_date": dueDate,
      "completed": completed,
      "completed_by": completedBy,
      "completed_on": completedOn,
      "recurring": recurring ? 1 : 0,
      "frequency_hours": frequencyHours,
      "always_assigned": alwaysAssigned ? 1 : 0,
      "project_id": projectId, // <-- Include projectId in JSON
    };
  }
}
