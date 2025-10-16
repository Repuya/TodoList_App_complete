import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F2FA),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.deepPurple,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          elevation: 3,
        ),
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final CollectionReference _todosCollection =
  FirebaseFirestore.instance.collection('todos');

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    if (_taskController.text.trim().isEmpty) return;
    try {
      await _todosCollection.add({
        'task': _taskController.text.trim(),
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _taskController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task Added Successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleTaskCompletion(String docId, bool currentStatus) async {
    try {
      await _todosCollection.doc(docId).update({
        'completed': !currentStatus,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(String docId) async {
    try {
      await _todosCollection.doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task Deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editTask(String docId, String currentTask) async {
    final controller = TextEditingController(text: currentTask);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Task',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  await _todosCollection.doc(docId).update({
                    'task': controller.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task Updated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('MMM d, y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My to do List'),
      ),
      body: Column(
        children: [
          // Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'New Task',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_task, color: Colors.deepPurple),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // Task List Section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _todosCollection
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.deepPurple),
                        SizedBox(height: 16),
                        Text(
                          'No tasks yet',
                          style: TextStyle(fontSize: 18, color: Colors.deepPurple),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a task to get started',
                          style: TextStyle(color: Colors.purpleAccent),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final task = data['task'] ?? '';
                    final completed = data['completed'] ?? false;
                    final timestamp = data['createdAt'] as Timestamp?;

                    return Card(
                      color: completed
                          ? Colors.deepPurple[50]
                          : Colors.white,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: completed,
                          activeColor: Colors.deepPurple,
                          onChanged: (_) =>
                              _toggleTaskCompletion(doc.id, completed),
                        ),
                        title: Text(
                          task,
                          style: TextStyle(
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: completed
                                ? Colors.purpleAccent
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: timestamp != null
                            ? Text(
                          _formatTimestamp(timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.deepPurple),
                              onPressed: () => _editTask(doc.id, task),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.purpleAccent,
                                size: 20,
                              ),
                              onPressed: () => _deleteTask(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
