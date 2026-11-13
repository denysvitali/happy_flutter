import 'package:flutter/foundation.dart';

/// Why an agent wrote to the user's Inbox.
///
/// happy-cli-go's `inbox_send` tool accepts exactly these kinds; anything
/// else is dropped while parsing so a malformed blob never renders.
enum InboxKind {
  goalReached('goal_reached'),
  question('question'),
  blocked('blocked');

  const InboxKind(this.wire);

  final String wire;

  static InboxKind? fromWire(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }

  /// Questions and blockers wait on the user; a reached goal does not.
  bool get awaitsUser => this != InboxKind.goalReached;
}

/// One high-priority message an agent delivered to the user's Inbox.
///
/// Stored by happy-cli-go in the session's encrypted `metadata.inbox`
/// (bounded to the 20 most recent per session). Timestamps are
/// milliseconds since epoch.
@immutable
class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.kind,
    required this.subject,
    required this.body,
    required this.createdAt,
    this.options = const <String>[],
    this.sessionId,
  });

  final String id;
  final InboxKind kind;
  final String subject;
  final String body;
  final List<String> options;
  final String? sessionId;
  final int createdAt;

  /// Parses one entry, returning `null` for anything malformed.
  static InboxMessage? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = InboxKind.fromWire(json['kind']);
    final subject = json['subject'];
    final body = json['body'];
    final createdAt = json['createdAt'];
    if (id is! String || id.isEmpty || kind == null) return null;
    if (subject is! String || subject.trim().isEmpty) return null;
    if (createdAt is! num) return null;
    final rawOptions = json['options'];
    final sessionId = json['sessionId'];
    return InboxMessage(
      id: id,
      kind: kind,
      subject: subject.trim(),
      body: body is String ? body : '',
      createdAt: createdAt.toInt(),
      options: rawOptions is List
          ? List.unmodifiable(
              rawOptions.whereType<String>().where((o) => o.isNotEmpty),
            )
          : const <String>[],
      sessionId: sessionId is String && sessionId.isNotEmpty ? sessionId : null,
    );
  }

  /// Parses `metadata.inbox`; `null` when the key is absent or not a list.
  static List<InboxMessage>? listFromJson(Object? value) {
    if (value is! List) return null;
    return List.unmodifiable(value.map(tryParse).whereType<InboxMessage>());
  }

  static List<Map<String, dynamic>>? listToJson(List<InboxMessage>? value) =>
      value?.map((m) => m.toJson()).toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.wire,
    'subject': subject,
    'body': body,
    if (options.isNotEmpty) 'options': options,
    if (sessionId != null) 'sessionId': sessionId,
    'createdAt': createdAt,
  };

  @override
  bool operator ==(Object other) =>
      other is InboxMessage &&
      other.id == id &&
      other.kind == kind &&
      other.subject == subject &&
      other.body == body &&
      listEquals(other.options, options) &&
      other.sessionId == sessionId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    subject,
    body,
    Object.hashAll(options),
    sessionId,
    createdAt,
  );
}
