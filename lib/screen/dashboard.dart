import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:reminddong_app/models/todo.dart';
import 'package:reminddong_app/models/user.dart';
import 'package:reminddong_app/providers/theme_provider.dart';
import 'package:reminddong_app/services/auth_service.dart';
import 'package:reminddong_app/services/database_helper.dart';
import 'add_edit_task_page.dart';

enum FilterType { all, pending, completed }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<Todo> _todos = [];
  User? _currentUser;
  FilterType _currentFilter = FilterType.all;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = await _authService.getCurrentUser();
    if (_currentUser != null) {
      await _loadTodos();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadTodos() async {
    if (_currentUser == null) return;

    List<Todo> todos;
    switch (_currentFilter) {
      case FilterType.all:
        todos = await _dbHelper.getTodosByUserId(_currentUser!.id!);
        break;
      case FilterType.pending:
        todos = await _dbHelper.getPendingTodos(_currentUser!.id!);
        break;
      case FilterType.completed:
        todos = await _dbHelper.getCompletedTodos(_currentUser!.id!);
        break;
    }

    setState(() {
      _todos = todos;
    });
  }

  Future<void> _toggleTodoCompletion(Todo todo) async {
    await _dbHelper.toggleTodoCompletion(todo.id!, !todo.isCompleted);
    await _loadTodos();
  }

  Future<void> _deleteTodo(int todoId) async {
    await _dbHelper.deleteTodo(todoId);
    await _loadTodos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted')),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate == today) {
      return 'Today';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (taskDate.isBefore(today)) {
      return 'Overdue';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Color _getDueDateColor(DateTime? date) {
    if (date == null) return Colors.grey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate.isBefore(today)) {
      return Colors.red;
    } else if (taskDate == today) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back button
        title: const Text(
          'RemindDong',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_currentUser != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface
                        : Colors.blue.shade50,
                    child: Text(
                      'Hello, ${_currentUser!.name}! 👋',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All', FilterType.all),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', FilterType.pending),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', FilterType.completed),
                    ],
                  ),
                ),
                Expanded(
                  child: _todos.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadTodos,
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _todos.length,
                            onReorder: (oldIndex, newIndex) async {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = _todos.removeAt(oldIndex);
                                _todos.insert(newIndex, item);
                              });
                              await _dbHelper.updateTaskOrder(_todos);
                            },
                            itemBuilder: (context, index) {
                              return _buildTaskCard(_todos[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditTaskPage(userId: _currentUser!.id!),
            ),
          );
          if (result == true) {
            await _loadTodos();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterType type) {
    final isSelected = _currentFilter == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = type;
        });
        _loadTodos();
      },
      selectedColor: Colors.blue.shade200,
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentFilter) {
      case FilterType.pending:
        message = 'No pending tasks!';
        icon = Icons.check_circle_outline;
        break;
      case FilterType.completed:
        message = 'No completed tasks yet';
        icon = Icons.playlist_add_check;
        break;
      default:
        message = 'No tasks yet.\nTap + to add your first task!';
        icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Todo todo) {
    return Card(
      key: Key(todo.id.toString()),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (value) => _toggleTodoCompletion(todo),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted 
                ? Colors.grey 
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todo.description != null && todo.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                todo.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: todo.isCompleted 
                      ? Colors.grey 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(todo.priority),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  todo.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getPriorityColor(todo.priority),
                  ),
                ),
                if (todo.dueDate != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: _getDueDateColor(todo.dueDate),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(todo.dueDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getDueDateColor(todo.dueDate),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditTaskPage(
                      userId: _currentUser!.id!,
                      todo: todo,
                    ),
                  ),
                );
                if (result == true) {
                  await _loadTodos();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Task'),
                    content: const Text('Are you sure you want to delete this task?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _deleteTodo(todo.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
