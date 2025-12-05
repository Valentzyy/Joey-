import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_model.dart';
import '../models/category_item.dart';

class TaskListPage extends StatefulWidget {
  final CategoryItem category;
  const TaskListPage({super.key, required this.category});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final TextEditingController _taskC = TextEditingController();
  final List<Task> _tasks = [];

  late final String _prefsKey;

  @override
  void dispose() {
    _taskC.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _prefsKey = 'tasks_${widget.category.id}';
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final List<dynamic> arr = json.decode(raw) as List<dynamic>;
      final loaded = arr.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      setState(() {
        _tasks.clear();
        _tasks.addAll(loaded);
      });
    } catch (_) {
      // ignore malformed data
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final arr = _tasks.map((t) => t.toJson()).toList();
    await prefs.setString(_prefsKey, json.encode(arr));
  }

  void _addTask(String title) {
    if (title.trim().isEmpty) return;
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: '',
      categoryId: widget.category.id,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    setState(() {
      _tasks.insert(0, task);
    });
    _taskC.clear();
    _saveTasks();
  }

  void _toggleComplete(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;
    });
    _saveTasks();
  }

  void _deleteTask(Task task) {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task deleted')),
    );
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.category.color.withValues(alpha: 0.08),
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: widget.category.color,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              color: Colors.black12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: task.isCompleted,
                              onChanged: (_) => _toggleComplete(task),
                            ),
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  color: task.isCompleted ? Colors.grey : Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTask(task),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskC,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Add new task...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _addTask,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.category.color,
                    minimumSize: const Size(55, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _addTask(_taskC.text),
                  child: const Icon(Icons.add, size: 28),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
