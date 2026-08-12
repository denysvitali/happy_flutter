/// Task list models with drag-and-drop support
library;

/// Task item state
enum TodoState {
  pending,
  inProgress,
  completed,
  canceled;

  static TodoState fromString(String value) {
    switch (value) {
      case 'in_progress':
      case 'in-progress':
      case 'in progress':
      case 'inProgress':
        return inProgress;
      case 'completed':
        return completed;
      case 'cancelled':
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
    this.description,
    this.parentId,
    this.dependencies = const [],
    this.dueAt,
    this.sessionId,
    this.completedAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: '${json['id'] ?? ''}',
      content:
          (json['content'] as String?) ?? (json['subject'] as String?) ?? '',
      status: TodoState.fromString('${json['status'] ?? 'pending'}'),
      priority: (json['priority'] as String?) ?? 'medium',
      order: _asInt(json['order']) ?? 0,
      description: json['description'] as String?,
      parentId: json['parentId'] as String?,
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      dueAt: _asInt(json['dueAt']),
      createdAt: _asInt(json['createdAt']) ?? 0,
      updatedAt: _asInt(json['updatedAt']) ?? 0,
      sessionId: json['sessionId'] as String?,
      completedAt: _asInt(json['completedAt']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

  /// Parses the `metadata.todos` list the Happy MCP persists.
  static List<TodoItem>? listFromJson(dynamic value) {
    if (value is! List) return null;
    final out = <TodoItem>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final item = TodoItem.fromJson(Map<String, dynamic>.from(entry));
      if (item.id.isEmpty || item.content.isEmpty) continue;
      out.add(item);
    }
    return out;
  }

  final String id;
  final String content;
  final TodoState status;
  final String priority; // 'low', 'medium', 'high', 'critical'
  final int order;
  final String? description;
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
      'description': description,
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
    String? description,
    bool clearDescription = false,
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
      description: clearDescription ? null : (description ?? this.description),
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
