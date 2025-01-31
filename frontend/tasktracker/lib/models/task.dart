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

  Task({
    required this.id,
    required this.title,
    this.assignedTo,
    this.creationDate,
    this.dueDate,
    required this.completed,
    this.completedBy,
    this.completedOn,
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
    );
  }
}
