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
    this.agentId,
    this.dependencies = const [],
    this.dueAt,
    this.sessionId,
    this.path,
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
      agentId: json['agentId'] as String?,
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      dueAt: _asInt(json['dueAt']),
      createdAt: _asInt(json['createdAt']) ?? 0,
      updatedAt: _asInt(json['updatedAt']) ?? 0,
      sessionId: json['sessionId'] as String?,
      path: json['path'] as String?,
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

  /// Like [listFromJson], but drops items stamped for a different session.
  ///
  /// Unstamped items are kept only when the blob has no stamped rows, so a
  /// cloned metadata document cannot leak another session's list.
  static List<TodoItem>? listFromJsonForSession(
    dynamic value,
    String sessionId,
  ) {
    final parsed = listFromJson(value);
    if (parsed == null) return null;
    final hasStamped = parsed.any((item) => (item.sessionId ?? '').isNotEmpty);
    return [
      for (final item in parsed)
        if (_belongsToSession(item, sessionId, hasStamped)) item,
    ];
  }

  static bool _belongsToSession(
    TodoItem item,
    String sessionId,
    bool hasStamped,
  ) {
    final stamped = item.sessionId ?? '';
    if (stamped.isNotEmpty) return stamped == sessionId;
    return !hasStamped;
  }

  final String id;
  final String content;
  final TodoState status;
  final String priority; // 'low', 'medium', 'high', 'critical'
  final int order;
  final String? description;
  final String? parentId;
  final String? agentId;
  final List<String> dependencies;
  final int? dueAt;
  final int createdAt;
  final int updatedAt;
  final String? sessionId;
  final String? path;
  final int? completedAt;

  /// Parents precede their children; missing parents are treated as roots.
  static List<TodoItem> hierarchyOrder(List<TodoItem> items) {
    final byId = {for (final item in items) item.id: item};
    final sorted = [...items]..sort((a, b) => a.order.compareTo(b.order));
    final result = <TodoItem>[];
    final visited = <String>{};

    void append(TodoItem item) {
      if (!visited.add(item.id)) return;
      result.add(item);
      for (final child in sorted) {
        if (child.parentId == item.id) append(child);
      }
    }

    for (final item in sorted) {
      if (!byId.containsKey(item.parentId)) append(item);
    }
    // Legacy or malformed snapshots can contain cycles.
    for (final item in sorted) {
      append(item);
    }
    return result;
  }

  static int depthIn(TodoItem item, List<TodoItem> items) {
    final byId = {for (final entry in items) entry.id: entry};
    final visited = <String>{item.id};
    var depth = 0;
    var parentId = item.parentId;
    while (parentId != null && visited.add(parentId)) {
      final parent = byId[parentId];
      if (parent == null) break;
      depth++;
      parentId = parent.parentId;
    }
    return depth;
  }

  static String? effectiveAgentId(TodoItem item, List<TodoItem> items) {
    final byId = {for (final entry in items) entry.id: entry};
    final visited = <String>{};
    var current = item;
    while (visited.add(current.id)) {
      if (current.agentId case final agentId? when agentId.isNotEmpty) {
        return agentId;
      }
      final parent = byId[current.parentId];
      if (parent == null) break;
      current = parent;
    }
    return null;
  }

  /// Keep completed rows visible until a later snapshot adds a new row.
  /// A completed ancestor remains while any child is still visible.
  static List<TodoItem> expireCompletedOnAdd(
    List<TodoItem> previous,
    List<TodoItem> next,
  ) {
    final priorIds = {for (final item in previous) item.id};
    if (!next.any((item) => !priorIds.contains(item.id))) return next;
    final expiredCandidates = {
      for (final item in previous)
        if (item.status.isTerminal) item.id,
    };
    var remaining = [...next];
    while (true) {
      final parents = {
        for (final item in remaining)
          if (item.parentId != null) item.parentId,
      };
      final kept = remaining.where((item) {
        return !expiredCandidates.contains(item.id) ||
            !item.status.isTerminal ||
            parents.contains(item.id);
      }).toList();
      if (kept.length == remaining.length) return remaining;
      remaining = kept;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'status': status.value,
      'priority': priority,
      'order': order,
      'description': description,
      'parentId': parentId,
      'agentId': agentId,
      'dependencies': dependencies,
      'dueAt': dueAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sessionId': sessionId,
      'path': path,
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
    String? agentId,
    bool clearAgentId = false,
    List<String>? dependencies,
    int? dueAt,
    int? createdAt,
    int? updatedAt,
    String? sessionId,
    String? path,
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
      agentId: clearAgentId ? null : (agentId ?? this.agentId),
      dependencies: dependencies != null
          ? List<String>.from(dependencies)
          : List<String>.from(this.dependencies),
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: sessionId ?? this.sessionId,
      path: path ?? this.path,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
