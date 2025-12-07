import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import '../models/category_item.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final List<CategoryItem> categories = const [
    CategoryItem(id: '1', name: 'School', emoji: '📚', colorValue: 0xFFC8956E),
    CategoryItem(id: '2', name: 'Home', emoji: '🏠', colorValue: 0xFFD4A574),
    CategoryItem(id: '3', name: 'Work', emoji: '💼', colorValue: 0xFF8B6F47),
    CategoryItem(id: '4', name: 'Personal', emoji: '❤️', colorValue: 0xFFB8860B),
  ];

  Map<String, List<Task>> _allTasks = {};
  final TextEditingController _taskC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllTasks();
  }

  @override
  void dispose() {
    _taskC.dispose();
    super.dispose();
  }

Future<void> _loadAllTasks() async {
  final prefs = await SharedPreferences.getInstance();
  final newTasks = <String, List<Task>>{};
  final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';

  for (var cat in categories) {
    final raw = prefs.getString('tasks_${userEmail}_${cat.id}');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> arr = json.decode(raw) as List<dynamic>;
        final loaded = arr.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        newTasks[cat.id] = loaded;
      } catch (_) {
        newTasks[cat.id] = [];
      }
    } else {
      newTasks[cat.id] = [];
    }
  }

  setState(() {
    _allTasks = newTasks;
  });
}


  Future<void> _saveTasks(String categoryId) async {
  final prefs = await SharedPreferences.getInstance();
  final tasks = _allTasks[categoryId] ?? [];
  final arr = tasks.map((t) => t.toJson()).toList();
  final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';

  await prefs.setString('tasks_${userEmail}_$categoryId', json.encode(arr));
}

  void _addTask(String categoryId, String title) {
    if (title.trim().isEmpty) return;
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: '',
      categoryId: categoryId,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    setState(() {
      _allTasks[categoryId] ??= [];
      _allTasks[categoryId]!.insert(0, task);
    });
    _taskC.clear();
    _saveTasks(categoryId);
  }

  void _toggleComplete(String categoryId, Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;
    });
    _saveTasks(categoryId);
  }

  void _deleteTask(String categoryId, Task task) {
    setState(() {
      _allTasks[categoryId]?.removeWhere((t) => t.id == task.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task deleted')),
    );
    _saveTasks(categoryId);
  }

  void _showAddTaskDialog() {
    String? selectedCategoryId;
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Dropdown
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedCategoryId,
                    hint: const Text('Select Category'),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child: Row(
                          children: [
                            Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Text(cat.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Task Title Input
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'Enter task name...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(213, 139, 111, 71),
                  ),
                  onPressed: () {
                    if (selectedCategoryId != null && titleController.text.isNotEmpty) {
                      _addTask(selectedCategoryId!, titleController.text);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select category and enter task')),
                      );
                    }
                  },
                  child: const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _logout(BuildContext context) {
    final auth = AuthService();
    auth.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        title: const Text('My Tasks', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8B6F47),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Builder(builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  return Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF8B6F47)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user?.email ?? 'No email',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Color(0xFF8B6F47)),
                    const SizedBox(width: 12),
                    const Text('Edit Profile'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 12),
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header dengan gambar beruang custom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B6F47).withValues(alpha: 0.1),
                  const Color.fromARGB(164, 138, 111, 48).withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Column(
              children: [
                // Joey Bear from asset
                SizedBox(
                height: 40,
                width: 80,
                child: Transform.scale(
                  scale: 2.9,
                  child: SvgPicture.asset('assets/beruang.svg'),
                ),
              ),
                const SizedBox(height: 12),
                Text(
                  'Welcome Back, ${FirebaseAuth.instance.currentUser?.displayName ?? 'Friend'}!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B6F47),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s organize your tasks today 🎯',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Categories Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final tasks = _allTasks[cat.id] ?? [];
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.1),
                      border: Border.all(color: cat.color, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Category Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cat.color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                cat.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Task List
                        Expanded(
                          child: tasks.isEmpty
                              ? Center(
                                  child: Text(
                                    'No tasks',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: tasks.length,
                                  itemBuilder: (context, taskIndex) {
                                    final task = tasks[taskIndex];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: cat.color.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: task.isCompleted,
                                            activeColor: cat.color,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (_) =>
                                                _toggleComplete(cat.id, task),
                                          ),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                decoration: task.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: task.isCompleted
                                                    ? Colors.grey
                                                    : Colors.black,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                _deleteTask(cat.id, task),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.red[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF8B6F47),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
