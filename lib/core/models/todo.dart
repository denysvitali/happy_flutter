/// Task list models with drag-and-drop support
library;

/// Task item state
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

/// Task item with ordering
class TodoItem {
  TodoItem({
    required this.id,
    required this.content,
    required this.status,
    required this.priority,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.dependencies = const [],
    this.dueAt,
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
    bool clearParentId = false,
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
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      dependencies: dependencies != null
          ? List<String>.from(dependencies)
          : List<String>.from(this.dependencies),
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: sessionId ?? this.sessionId,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

