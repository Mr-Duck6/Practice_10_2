import 'package:hive/hive.dart';
import '../models/task.dart';

class TaskAnalytics {
  final Box<Task> _box = Hive.box<Task>('tasks');

  int get total => _box.length;
  int get completed => _box.values.where((task) => task.isCompleted).length;
  int get pending => total - completed;

  List<Task> get overdue => _box.values
      .where((task) =>
          !task.isCompleted && task.dueDate.isBefore(DateTime.now()))
      .toList();

  double get productivity => total == 0 ? 0 : completed / total * 100;

  double? get averageCompletionHours {
    final completedTasks = _box.values
        .where((task) => task.isCompleted && task.completedAt != null)
        .toList();
    if (completedTasks.isEmpty) return null;

    final totalHours = completedTasks.fold<double>(
      0,
      (sum, task) =>
          sum + task.completedAt!.difference(task.createdAt).inMinutes / 60,
    );
    return totalHours / completedTasks.length;
  }
}
