import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/task.dart';

class BackupManager {
  final Box<Task> _taskBox = Hive.box<Task>('tasks');

  Future<Directory> get _backupDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final directory = Directory('${appDir.path}/backups');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // Створює копію у внутрішній папці застосунку та пропонує зберегти її окремо.
  Future<File> exportToJson({bool askWhereToSave = true}) async {
    final now = DateTime.now();
    final data = {
      'version': '1.0',
      'exportedAt': now.toIso8601String(),
      'tasksCount': _taskBox.length,
      'tasks': _taskBox.values.map(_taskToJson).toList(),
    };

    final directory = await _backupDirectory;
    final fileName = 'backup_${now.millisecondsSinceEpoch}.json';
    final file = File('${directory.path}/$fileName');
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);

    if (askWhereToSave) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Зберегти резервну копію',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonString)),
      );
    }
    await cleanupOldBackups();
    return file;
  }

  Map<String, dynamic> _taskToJson(Task task) => {
        'title': task.title,
        'description': task.description,
        'dueDate': task.dueDate.toIso8601String(),
        'priority': task.priority,
        'isCompleted': task.isCompleted,
        'subtasks': task.subtasks,
        'createdAt': task.createdAt.toIso8601String(),
        'completedAt': task.completedAt?.toIso8601String(),
      };

  Future<int> importFromText(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic> || decoded['tasks'] is! List) {
      throw const FormatException('Неправильний формат резервної копії.');
    }

    final importedTasks = (decoded['tasks'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Помилка у записі задачі.');
      }
      return Task(
        title: item['title'] as String? ?? '',
        description: item['description'] as String? ?? '',
        dueDate: DateTime.parse(item['dueDate'] as String),
        priority: _validPriority(item['priority'] as String?),
        isCompleted: item['isCompleted'] as bool? ?? false,
        subtasks: (item['subtasks'] as List? ?? []).cast<String>(),
        createdAt: DateTime.tryParse(item['createdAt'] as String? ?? '') ??
            DateTime.now(),
        completedAt: DateTime.tryParse(item['completedAt'] as String? ?? ''),
      );
    }).toList();

    // Імпорт замінює поточний список задач.
    await _taskBox.clear();
    await _taskBox.addAll(importedTasks);
    return importedTasks.length;
  }

  String _validPriority(String? value) {
    if (['low', 'medium', 'high'].contains(value)) return value!;
    return 'medium';
  }

  Future<int> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return -1;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const FormatException('Не вдалося прочитати файл.');
    }
    return importFromText(utf8.decode(bytes));
  }

  Future<List<File>> listBackups() async {
    final directory = await _backupDirectory;
    final result = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
        result.add(entity);
      }
    }
    result.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return result;
  }

  Future<int> restoreBackup(File file) async {
    return importFromText(await file.readAsString());
  }

  Future<void> deleteBackup(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<DateTime?> getLastBackupDate() async {
    final backups = await listBackups();
    if (backups.isEmpty) return null;
    return backups.first.lastModified();
  }

  // Автоматичний backup виконується під час запуску, якщо минула доба.
  Future<void> autoBackup() async {
    try {
      final lastBackup = await getLastBackupDate();
      if (lastBackup == null ||
          DateTime.now().difference(lastBackup).inHours >= 24) {
        await exportToJson(askWhereToSave: false);
      }
    } catch (_) {
      // Помилка автоматичної копії не повинна блокувати запуск застосунку.
    }
  }

  Future<void> cleanupOldBackups({int keepCount = 10}) async {
    final backups = await listBackups();
    if (backups.length > keepCount) {
      for (final file in backups.skip(keepCount)) {
        await file.delete();
      }
    }
  }
}
