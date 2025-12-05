import 'package:flutter/material.dart';
import '../models/task_model.dart';

class CompletedTasksScreen extends StatelessWidget {
  final Map<String, List<Task>> allTasks;

  const CompletedTasksScreen({super.key, required this.allTasks});

  @override
  Widget build(BuildContext context) {
    final List<Task> completed = [];

    allTasks.forEach((key, tasks) {
      completed.addAll(tasks.where((t) => t.isCompleted == true));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Completed Tasks"),
        backgroundColor: Color(0xFF8B6F47),
      ),
      body: completed.isEmpty
          ? const Center(child: Text("No completed tasks"))
          : ListView.builder(
              itemCount: completed.length,
              itemBuilder: (context, i) {
                final task = completed[i];
                return ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text(
                    task.title,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
