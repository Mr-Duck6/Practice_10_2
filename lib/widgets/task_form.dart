import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/task.dart';

class TaskForm extends StatefulWidget {
  final Task? task;

  const TaskForm({super.key, this.task});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _dueDate;
  late String _priority;
  late List<String> _subtasks;
  final _subtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _dueDate = task?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    _priority = task?.priority ?? 'medium';
    _subtasks = List<String>.from(task?.subtasks ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.task == null ? 'Нова задача' : 'Редагувати задачу',
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Назва задачі',
                    border: OutlineInputBorder()),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Введіть назву задачі'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Опис', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                    labelText: 'Пріоритет', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Низький')),
                  DropdownMenuItem(value: 'medium', child: Text('Середній')),
                  DropdownMenuItem(value: 'high', child: Text('Високий')),
                ],
                onChanged: (value) =>
                    setState(() => _priority = value ?? 'medium'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: const Text('Дата виконання'),
                subtitle: Text(
                    '${_dueDate.day.toString().padLeft(2, '0')}.${_dueDate.month.toString().padLeft(2, '0')}.${_dueDate.year}'),
                onTap: _selectDate,
              ),
              const Divider(),
              const Text('Підзадачі',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskController,
                      decoration: const InputDecoration(
                          hintText: 'Назва підзадачі'),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  IconButton(
                      onPressed: _addSubtask,
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              ..._subtasks.asMap().entries.map((entry) {
                final done = entry.value.startsWith('[x] ');
                final label =
                    entry.value.replaceFirst(RegExp(r'^\[(x| )\] '), '');
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      done ? Icons.check_box : Icons.check_box_outline_blank),
                  title: Text(label),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _subtasks.removeAt(entry.key)),
                  ),
                  onTap: () => setState(() {
                    _subtasks[entry.key] =
                        '${done ? '[ ]' : '[x]'} $label';
                  }),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Зберегти задачу'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add('[ ] $text');
      _subtaskController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.task == null) {
      await Hive.box<Task>('tasks').add(Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        subtasks: _subtasks,
      ));
    } else {
      final task = widget.task!;
      task
        ..title = _titleController.text.trim()
        ..description = _descriptionController.text.trim()
        ..dueDate = _dueDate
        ..priority = _priority
        ..subtasks = _subtasks;
      await task.save();
    }

    if (mounted) Navigator.pop(context);
  }
}
