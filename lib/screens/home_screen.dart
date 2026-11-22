import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../services/backup_manager.dart';
import '../services/task_analytics.dart';
import '../widgets/task_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  String _priorityFilter = 'all';
  bool _sortAscending = true;

  final _backupManager = BackupManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(child: _buildCurrentPage()),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () => _openTaskForm(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.checklist_rounded), label: 'Задачі'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'Статистика'),
          NavigationDestination(
              icon: Icon(Icons.cloud_sync_rounded), label: 'Backup'),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    if (_index == 0) return _buildTasksPage();
    if (_index == 1) return _buildDashboardPage();
    return _buildBackupsPage();
  }

  Widget _buildTasksPage() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Task>('tasks').listenable(),
      builder: (context, Box<Task> box, _) {
        final tasks = box.values.where((task) {
          return _priorityFilter == 'all' ||
              task.priority == _priorityFilter;
        }).toList()
          ..sort((a, b) => _sortAscending
              ? a.dueDate.compareTo(b.dueDate)
              : b.dueDate.compareTo(a.dueDate));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priorityFilter,
                      decoration: const InputDecoration(
                        labelText: 'Пріоритет',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Усі')),
                        DropdownMenuItem(value: 'low', child: Text('Низький')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Середній')),
                        DropdownMenuItem(value: 'high', child: Text('Високий')),
                      ],
                      onChanged: (value) =>
                          setState(() => _priorityFilter = value ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'Змінити порядок сортування',
                    onPressed: () =>
                        setState(() => _sortAscending = !_sortAscending),
                    icon: Icon(_sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const _EmptyState(
                      icon: Icons.task_alt,
                      title: 'Поки немає задач',
                      subtitle: 'Натисніть +, щоб додати першу задачу.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) =>
                          _taskCard(tasks[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _taskCard(Task task) {
    final color = _priorityColor(task.priority);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (value) async {
                    task.isCompleted = value ?? false;
                    task.completedAt =
                        task.isCompleted ? DateTime.now() : null;
                    await task.save();
                  },
                ),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? Colors.grey : null,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _openTaskForm(task: task);
                    if (value == 'delete') _confirmDelete(task);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Редагувати')),
                    PopupMenuItem(value: 'delete', child: Text('Видалити')),
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Text(task.description,
                    style: const TextStyle(color: Colors.black54)),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _smallTag(
                    _priorityName(task.priority),
                    color,
                  ),
                  _smallTag(
                    'До ${_dateText(task.dueDate)}',
                    task.dueDate.isBefore(DateTime.now()) &&
                            !task.isCompleted
                        ? Colors.red
                        : Colors.blueGrey,
                  ),
                  if (task.subtasks.isNotEmpty)
                    _smallTag(
                      'Підзадачі: ${task.subtasks.where((s) => s.startsWith('[x] ')).length}/${task.subtasks.length}',
                      Colors.teal,
                    ),
                ],
              ),
            ),
            if (task.subtasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 8),
                child: Column(
                  children: task.subtasks.asMap().entries.map((entry) {
                    final done = entry.value.startsWith('[x] ');
                    final label = entry.value.replaceFirst(
                        RegExp(r'^\[(x| )\] '), '');
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: done,
                      title: Text(label,
                          style: TextStyle(
                            fontSize: 13,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          )),
                      onChanged: (value) async {
                        task.subtasks[entry.key] =
                            '${value == true ? '[x]' : '[ ]'} $label';
                        await task.save();
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardPage() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Task>('tasks').listenable(),
      builder: (context, Box<Task> box, _) {
        final analytics = TaskAnalytics();
        final average = analytics.averageCompletionHours;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Твоя продуктивність',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${analytics.productivity.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: analytics.productivity / 100,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 8),
                    const Text('Відсоток виконаних задач'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statCard('Усього', analytics.total,
                        Icons.list_alt, Colors.indigo)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard('Виконано', analytics.completed,
                        Icons.check_circle, Colors.green)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _statCard('Очікують', analytics.pending,
                        Icons.pending_actions, Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard('Прострочено', analytics.overdue.length,
                        Icons.warning_amber, Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Середній час виконання'),
                subtitle: Text(average == null
                    ? 'Поки недостатньо даних'
                    : '${average.toStringAsFixed(1)} год.'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Прострочені задачі',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (analytics.overdue.isEmpty)
              const Card(
                  child: ListTile(
                      leading: Icon(Icons.celebration_outlined),
                      title: Text('Немає прострочених задач')))
            else
              ...analytics.overdue.map((task) => Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(task.title),
                      subtitle: Text('Термін: ${_dateText(task.dueDate)}'),
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildBackupsPage() {
    return FutureBuilder<List<File>>(
      future: _backupManager.listBackups(),
      builder: (context, snapshot) {
        final backups = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Резервні копії',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                'Копії зберігаються у внутрішній папці застосунку. Автоматична копія створюється під час запуску, якщо минуло 24 години.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _runBackup(),
              icon: const Icon(Icons.download),
              label: const Text('Створити backup та експортувати JSON'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _runImport(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Імпортувати JSON з файлу'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                    child: Text('Збережені копії',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
                Text('${backups.length} файлів',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (backups.isEmpty)
              const _EmptyState(
                  icon: Icons.folder_open,
                  title: 'Копій ще немає',
                  subtitle: 'Створіть першу резервну копію.')
            else
              ...backups.map(_backupCard),
          ],
        );
      },
    );
  }

  Widget _backupCard(File file) {
    final name = file.uri.pathSegments.last;
    final date = file.lastModifiedSync();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_dateText(date)} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'restore') {
              final confirm = await _confirm(
                'Відновити копію?',
                'Поточний список задач буде замінено даними з цього файлу.',
              );
              if (confirm) {
                try {
                  final count = await _backupManager.restoreBackup(file);
                  _message('Відновлено задач: $count');
                  setState(() {});
                } catch (e) {
                  _message('Помилка імпорту: $e');
                }
              }
            } else if (value == 'delete') {
              await _backupManager.deleteBackup(file);
              setState(() {});
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'restore', child: Text('Відновити')),
            PopupMenuItem(value: 'delete', child: Text('Видалити')),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text('$value',
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priorityName(String priority) {
    switch (priority) {
      case 'high':
        return 'Високий';
      case 'low':
        return 'Низький';
      default:
        return 'Середній';
    }
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Future<void> _openTaskForm({Task? task}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskForm(task: task),
    );
  }

  Future<void> _confirmDelete(Task task) async {
    final confirm = await _confirm(
        'Видалити задачу?', 'Цю дію неможливо буде скасувати.');
    if (confirm) await task.delete();
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Скасувати')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Продовжити')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runBackup() async {
    try {
      final file = await _backupManager.exportToJson();
      _message('Backup створено: ${file.uri.pathSegments.last}');
      setState(() {});
    } catch (e) {
      _message('Помилка backup: $e');
    }
  }

  Future<void> _runImport() async {
    final confirm = await _confirm(
      'Імпортувати задачі?',
      'Поточний список буде замінено даними з вибраного JSON-файлу.',
    );
    if (!confirm) return;
    try {
      final count = await _backupManager.importFromFile();
      if (count >= 0) {
        _message('Імпортовано задач: $count');
        setState(() {});
      }
    } catch (e) {
      _message('Помилка імпорту: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
