/// Todo list models with drag-and-drop support

/// Todo item state
enum TodoState {
  pending,
  inProgress,
  completed,
  canceled,
  ;

  static TodoState fromString(String value) {
    switch (value) {
      case 'inProgress':
        return inProgress;
      case 'completed':
        return completed;
      case 'canceled':
        return canceled;
      default:
        return pending;
    }
  }

  String get value {
    switch (this) {
      case pending:
        return 'pending';
      case inProgress:
        return 'inProgress';
      case completed:
        return 'completed';
      case canceled:
        return 'canceled';
    }
  }

  String get displayName {
    switch (this) {
      case pending:
        return 'Pending';
      case inProgress:
        return 'In Progress';
      case completed:
        return 'Completed';
      case canceled:
        return 'Canceled';
    }
  }

  bool get isTerminal => this == completed || this == canceled;
}

/// Todo item with ordering
class TodoItem {
  final String id;
  final String content;
  final TodoState status;
  final String priority; // 'low', 'medium', 'high', 'critical'
  final int order;
  final String? parentId;
  final List<String> dependencies;
  final int? dueAt;
  final int createdAt;
  final int updatedAt;
  final String? sessionId;
  final int? completedAt;

  TodoItem({
    required this.id,
    required this.content,
    required this.status,
    required this.priority,
    required this.order,
    this.parentId,
    this.dependencies = const [],
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.sessionId,
    this.completedAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      content: json['content'] as String,
      status: TodoState.fromString(json['status'] as String),
      priority: json['priority'] as String,
      order: json['order'] as int,
      parentId: json['parentId'] as String?,
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      dueAt: json['dueAt'] as int?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      sessionId: json['sessionId'] as String?,
      completedAt: json['completedAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'status': status.value,
      'priority': priority,
      'order': order,
      'parentId': parentId,
      'dependencies': dependencies,
      'dueAt': dueAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sessionId': sessionId,
      'completedAt': completedAt,
    };
  }

  TodoItem copyWith({
    String? id,
    String? content,
    TodoState? status,
    String? priority,
    int? order,
    String? parentId,
    List<String>? dependencies,
    int? dueAt,
    int? createdAt,
    int? updatedAt,
    String? sessionId,
    int? completedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      content: content ?? this.content,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      order: order ?? this.order,
      parentId: parentId ?? this.parentId,
      dependencies: dependencies ?? this.dependencies,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: sessionId ?? this.sessionId,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Todo list grouping by session
class TodoList {
  final String? sessionId;
  final List<TodoItem> items;
  final int updatedAt;

  TodoList({
    this.sessionId,
    required this.items,
    required this.updatedAt,
  });

  factory TodoList.fromJson(Map<String, dynamic> json) {
    return TodoList(
      sessionId: json['sessionId'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt: json['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'items': items.map((e) => e.toJson()).toList(),
      'updatedAt': updatedAt,
    };
  }

  /// Get items sorted by order
  List<TodoItem> get sortedItems {
    final sorted = List<TodoItem>.from(items);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  /// Get items by status
  List<TodoItem> get pendingItems =>
      items.where((e) => e.status == TodoState.pending).toList();

  List<TodoItem> get inProgressItems =>
      items.where((e) => e.status == TodoState.inProgress).toList();

  List<TodoItem> get completedItems =>
      items.where((e) => e.status == TodoState.completed).toList();

  /// Get root items (not subtasks)
  List<TodoItem> get rootItems =>
      items.where((e) => e.parentId == null).toList();

  /// Get subtasks for a parent
  List<TodoItem> getSubtasks(String parentId) {
    return items.where((e) => e.parentId == parentId).toList();
  }

  TodoList copyWith({
    String? sessionId,
    List<TodoItem>? items,
    int? updatedAt,
  }) {
    return TodoList(
      sessionId: sessionId ?? this.sessionId,
      items: items ?? this.items,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Reorder operation for drag-and-drop
class TodoReorder {
  final String todoId;
  final int newOrder;
  final String? newParentId;

  TodoReorder({
    required this.todoId,
    required this.newOrder,
    this.newParentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'todoId': todoId,
      'newOrder': newOrder,
      'newParentId': newParentId,
    };
  }
}
