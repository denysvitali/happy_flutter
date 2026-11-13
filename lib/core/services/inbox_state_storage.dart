import 'cached_storage.dart';

/// Local disposition of one Inbox message.
///
/// The message itself lives in encrypted session metadata; whether it was
/// opened, answered or filed away is the user's own triage and stays local,
/// like pins and folders.
class InboxMessageState {
  const InboxMessageState({
    this.read = false,
    this.done = false,
    this.reply,
    this.repliedAt,
  });

  final bool read;
  final bool done;

  /// Text the user sent from the Inbox, shown as their side of the thread.
  final String? reply;
  final int? repliedAt;

  bool get replied => repliedAt != null;

  static const InboxMessageState initial = InboxMessageState();

  InboxMessageState copyWith({
    bool? read,
    bool? done,
    String? reply,
    int? repliedAt,
  }) => InboxMessageState(
    read: read ?? this.read,
    done: done ?? this.done,
    reply: reply ?? this.reply,
    repliedAt: repliedAt ?? this.repliedAt,
  );

  static InboxMessageState fromJson(Object? json) {
    if (json is! Map) return initial;
    final reply = json['reply'];
    final repliedAt = json['repliedAt'];
    return InboxMessageState(
      read: json['read'] == true,
      done: json['done'] == true,
      reply: reply is String ? reply : null,
      repliedAt: repliedAt is num ? repliedAt.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (read) 'read': true,
    if (done) 'done': true,
    if (reply != null) 'reply': reply,
    if (repliedAt != null) 'repliedAt': repliedAt,
  };
}

/// Key for one message across sessions: message IDs are only unique within
/// their session.
String inboxMessageKey(String sessionId, String messageId) =>
    '$sessionId/$messageId';

/// MMKV-backed Inbox triage state keyed by [inboxMessageKey].
class InboxStateStorage extends CachedStorage<Map<String, InboxMessageState>> {
  InboxStateStorage({super.storage});

  static final InboxStateStorage instance = InboxStateStorage();

  /// Upper bound on retained entries; the oldest are evicted first. Servers
  /// keep at most 20 messages per session, so this covers far more history
  /// than can still be displayed.
  static const int maxEntries = 2000;

  @override
  String get key => 'inbox-message-state';

  @override
  String get logLabel => 'InboxStateStorage';

  @override
  Map<String, InboxMessageState> empty() => <String, InboxMessageState>{};

  @override
  Map<String, InboxMessageState> decode(dynamic json) {
    if (json is! Map) return empty();
    return <String, InboxMessageState>{
      for (final entry in json.entries)
        if (entry.key is String)
          entry.key as String: InboxMessageState.fromJson(entry.value),
    };
  }

  @override
  dynamic encode(Map<String, InboxMessageState> value) => <String, dynamic>{
    for (final entry in value.entries) entry.key: entry.value.toJson(),
  };

  /// Replaces one entry, evicting the oldest beyond [maxEntries].
  void put(String key, InboxMessageState state) => mutate((map) {
    map
      ..remove(key)
      ..[key] = state;
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
  });
}
