import 'package:hive/hive.dart';

@HiveType(typeId: 3)
class Task extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime dueDate;

  @HiveField(3)
  String priority;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  List<String> subtasks;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? completedAt;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
    List<String>? subtasks,
    DateTime? createdAt,
    this.completedAt,
  })  : subtasks = subtasks ?? [],
        createdAt = createdAt ?? DateTime.now();
}
