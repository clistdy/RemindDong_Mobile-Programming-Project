class Priority {
  static const String high = 'high';
  static const String medium = 'medium';
  static const String low = 'low';
  
  static List<String> get values => [high, medium, low];
}

class Todo {
  final int? id;
  final String title;
  final String? description;
  final bool isCompleted;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final int userId;
  final int order;

  Todo({
    this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.priority = Priority.medium,
    required this.createdAt,
    this.dueDate,
    required this.userId,
    this.order = 0,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'userId': userId,
      'order': order,
    };
  }
  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      isCompleted: (map['isCompleted'] as int) == 1,
      priority: map['priority'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: map['dueDate'] != null 
          ? DateTime.parse(map['dueDate'] as String) 
          : null,
      userId: map['userId'] as int,
      order: map['order'] as int? ?? 0,
    );
  }
  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
    String? priority,
    DateTime? createdAt,
    DateTime? dueDate,
    int? userId,
    int? order,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      userId: userId ?? this.userId,
      order: order ?? this.order,
    );
  }
}
