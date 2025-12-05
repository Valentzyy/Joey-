import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isEditing = false;

  // User data
  late String _name;
  late String _email;
  String _bio = '';

  // Tasks loaded from SharedPreferences (keys like 'tasks_<email>_<categoryId>')
  Map<String, List<Task>> _allTasks = {};

  // view state: 'profile' | 'mytasks' | 'completed'
  String _viewMode = 'profile';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _email = user?.email ?? 'No email';

    // Nama default dari email
    _name = _email.split('@')[0];

    _nameController = TextEditingController(text: _name);
    _bioController = TextEditingController(text: _bio);

    _loadProfile();
    _loadAllTasks();
  }

  // ===== Profile per akun =====
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';

      final savedBio = prefs.getString('profile_bio_$userEmail');
      final savedName = prefs.getString('profile_name_$userEmail');

      setState(() {
        if (savedBio != null && savedBio.isNotEmpty) {
          _bio = savedBio;
          _bioController.text = _bio;
        }

        if (savedName != null && savedName.isNotEmpty) {
          _name = savedName;
          _nameController.text = _name;
        } else {
          _name = _email.split('@')[0];
          _nameController.text = _name;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';
      await prefs.setString('profile_name_$userEmail', _name);
      await prefs.setString('profile_bio_$userEmail', _bio);
    } catch (_) {}
  }

  // ===== Tasks per akun =====
  Future<void> _loadAllTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, List<Task>> loaded = {};
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';

      for (final k in keys) {
        if (k.startsWith('tasks_${userEmail}_')) {
          final raw = prefs.getString(k);
          final catId = k.substring('tasks_${userEmail}_'.length);

          if (raw != null && raw.isNotEmpty) {
            try {
              final List<dynamic> arr = json.decode(raw) as List<dynamic>;
              final list = arr
                  .map((e) =>
                      Task.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
              loaded[catId] = list;
            } catch (_) {
              loaded[catId] = [];
            }
          } else {
            loaded[catId] = [];
          }
        }
      }

      setState(() {
        _allTasks = loaded;
      });
    } catch (_) {}
  }

  Future<void> _saveTasks(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = _allTasks[categoryId] ?? [];
    final arr = tasks.map((t) => t.toJson()).toList();
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';
    await prefs.setString('tasks_${userEmail}_$categoryId', json.encode(arr));
  }

  // ===== Edit profile =====
  Future<void> _toggleEditMode() async {
    if (_isEditing) {
      final newName = _nameController.text.trim();
      final newBio = _bioController.text.trim();

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && newName.isNotEmpty && newName != _name) {
          await user.updateDisplayName(newName);
          await user.reload();
        }

        setState(() {
          _name = newName.isNotEmpty ? newName : _name;
          _bio = newBio;
          _isEditing = false;
        });

        await _saveProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      }
    } else {
      setState(() {
        _nameController.text = _name;
        _bioController.text = _bio;
        _isEditing = true;
      });
    }
  }

  // ===== Logout =====
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final auth = AuthService();
              auth.logout();
              Navigator.pop(context);
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _enterView(String view) {
    setState(() {
      _viewMode = view;
    });
  }

  void _toggleComplete(String categoryId, Task task) {
    setState(() {
      final list = _allTasks[categoryId];
      if (list == null) return;
      final idx = list.indexWhere((t) => t.id == task.id);
      if (idx == -1) return;
      list[idx].isCompleted = !list[idx].isCompleted;
      list[idx].completedAt = list[idx].isCompleted ? DateTime.now() : null;
    });
    _saveTasks(categoryId);
  }

  void _deleteTask(String categoryId, Task task) {
    setState(() {
      _allTasks[categoryId]?.removeWhere((t) => t.id == task.id);
    });
    _saveTasks(categoryId);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task deleted')));
    }
  }

  int get _totalTasks {
    int s = 0;
    for (final v in _allTasks.values) {
      s += v.length;
    }
    return s;
  }

  int get _completedTasks {
    int s = 0;
    for (final v in _allTasks.values) {
      s += v.where((t) => t.isCompleted).length;
    }
    return s;
  }

  List<Task> get _flattenedTasks {
    final list = <Task>[];
    for (final v in _allTasks.values) {
      list.addAll(v);
    }
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(1970);
      final bTime = b.createdAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  List<Task> get _completedList =>
      _flattenedTasks.where((t) => t.isCompleted).toList();

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completionRate = _totalTasks > 0
        ? ((_completedTasks / _totalTasks) * 100).toStringAsFixed(0)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF8B6F47),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: _toggleEditMode,
          ),
        ],
        leading: _viewMode == 'profile'
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _enterView('profile'),
              ),
      ),
      body: _viewMode == 'profile'
          ? _buildProfileBody(completionRate)
          : _buildListViewBody(),
    );
  }

  Widget _buildProfileBody(String completionRate) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: const Color(0xFF8B6F47),
            padding: const EdgeInsets.only(top: 20, bottom: 30),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B6F47),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isEditing
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                              filled: true,
                              fillColor: Colors.white10,
                            ),
                          ),
                        )
                      : Text(
                          _name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  const SizedBox(height: 8),
                  Text(
                    _email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  children: [
                    _buildStatCard(
                      title: 'My Tasks',
                      value: _totalTasks.toString(),
                      icon: Icons.list_alt,
                      color: const Color(0xFFD4A574),
                      onTap: () => _enterView('mytasks'),
                    ),
                    _buildStatCard(
                      title: 'Completed',
                      value: _completedTasks.toString(),
                      icon: Icons.check_circle,
                      color: const Color(0xFFFFC107),
                      onTap: () => _enterView('completed'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListViewBody() {
    final title = _viewMode == 'mytasks' ? 'My Tasks' : 'Completed Tasks';
    final tasks = _viewMode == 'mytasks' ? _flattenedTasks : _completedList;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          color: const Color(0xFF8B6F47),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _viewMode == 'mytasks'
                          ? 'No tasks yet.'
                          : 'No completed tasks yet.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final categoryId = task.categoryId ?? 'unknown';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6)
                        ],
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) =>
                                _toggleComplete(categoryId, task),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.isCompleted
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  task.description ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (task.createdAt != null)
                                      Text(
                                        'Created: ${_formatDate(task.createdAt!)}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.black54),
                                      ),
                                    const SizedBox(width: 12),
                                    if (task.completedAt != null)
                                      Text(
                                        'Completed: ${_formatDate(task.completedAt!)}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.black54),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteTask(categoryId, task),
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$min';
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
