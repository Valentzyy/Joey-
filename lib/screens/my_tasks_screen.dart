import 'package:flutter/material.dart';
import '../models/task_model.dart';

class MyTasksScreen extends StatelessWidget {
  final Map<String, List<Task>> allTasks;

  const MyTasksScreen({super.key, required this.allTasks});

  @override
  Widget build(BuildContext context) {
    final List<Task> notCompleted = [];

    allTasks.forEach((key, tasks) {
      notCompleted.addAll(tasks.where((t) => t.isCompleted == false));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tasks"),
        backgroundColor: Color(0xFF8B6F47),
      ),
      body: notCompleted.isEmpty
          ? const Center(child: Text("No tasks available"))
          : ListView.builder(
              itemCount: notCompleted.length,
              itemBuilder: (context, i) {
                final task = notCompleted[i];
                return ListTile(
                  leading: Icon(Icons.circle_outlined),
                  title: Text(task.title),
                );
              },
            ),
    );
  }
}
