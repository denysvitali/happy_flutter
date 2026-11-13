import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/inbox_message.dart';
import '../../core/models/session.dart';
import '../../core/providers/sessions_notifier.dart';
import '../../core/services/inbox_state_storage.dart';
import '../../core/utils/session_utils.dart';

/// One Inbox row: an agent message plus the session that sent it.
///
/// Only the session fields the Inbox renders are captured, so session
/// churn (thinking, presence, usage) does not rebuild the Inbox.
@immutable
class InboxItem {
  const InboxItem({
    required this.sessionId,
    required this.sessionName,
    required this.avatarId,
    required this.message,
    this.flavor,
    this.archived = false,
  });

  factory InboxItem.from(Session session, InboxMessage message) => InboxItem(
    sessionId: session.id,
    sessionName: getSessionName(session),
    avatarId: getSessionAvatarId(session),
    flavor: session.metadata?.flavor,
    archived: session.archived,
    message: message,
  );

  final String sessionId;
  final String sessionName;
  final String avatarId;
  final String? flavor;
  final bool archived;
  final InboxMessage message;

  String get key => inboxMessageKey(sessionId, message.id);

  @override
  bool operator ==(Object other) =>
      other is InboxItem &&
      other.sessionId == sessionId &&
      other.sessionName == sessionName &&
      other.avatarId == avatarId &&
      other.flavor == flavor &&
      other.archived == archived &&
      other.message == message;

  @override
  int get hashCode =>
      Object.hash(sessionId, sessionName, avatarId, flavor, archived, message);
}

/// Inbox messages across every known session, newest first.
@immutable
class InboxCatalog {
  const InboxCatalog(this.items);

  factory InboxCatalog.fromSessions(Map<String, Session> sessions) {
    final items = <InboxItem>[
      for (final session in sessions.values)
        for (final message in session.metadata?.inbox ?? const <InboxMessage>[])
          // Messages stamped for another session came from cloned metadata.
          if (message.sessionId == null || message.sessionId == session.id)
            InboxItem.from(session, message),
    ]..sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt));
    return InboxCatalog(List.unmodifiable(items));
  }

  final List<InboxItem> items;

  @override
  bool operator ==(Object other) =>
      other is InboxCatalog && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}

final inboxCatalogProvider = Provider<InboxCatalog>(
  (ref) =>
      ref.watch(sessionsNotifierProvider.select(InboxCatalog.fromSessions)),
);

/// The user's local triage of Inbox messages (read, replied, done).
class InboxStateNotifier extends Notifier<Map<String, InboxMessageState>> {
  InboxStateNotifier([InboxStateStorage? storage])
    : _storage = storage ?? InboxStateStorage.instance;

  final InboxStateStorage _storage;

  @override
  Map<String, InboxMessageState> build() =>
      Map.unmodifiable(Map.of(_storage.cache));

  InboxMessageState stateOf(String key) =>
      state[key] ?? InboxMessageState.initial;

  void _put(String key, InboxMessageState next) {
    _storage.put(key, next);
    state = Map.unmodifiable({...state, key: next});
  }

  void markRead(String key) {
    final current = stateOf(key);
    if (current.read) return;
    _put(key, current.copyWith(read: true));
  }

  void markUnread(String key) {
    final current = stateOf(key);
    _put(
      key,
      InboxMessageState(
        done: current.done,
        reply: current.reply,
        repliedAt: current.repliedAt,
      ),
    );
  }

  void setDone(String key, {required bool done}) =>
      _put(key, stateOf(key).copyWith(done: done, read: true));

  void recordReply(String key, String text, {int? at}) => _put(
    key,
    stateOf(key).copyWith(
      read: true,
      reply: text,
      repliedAt: at ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );
}

final inboxStateProvider =
    NotifierProvider<InboxStateNotifier, Map<String, InboxMessageState>>(
      InboxStateNotifier.new,
    );

/// Which Inbox folder is shown.
enum InboxFolder { inbox, done }

/// Whether [item] still belongs in the main Inbox folder.
bool inboxItemIsOpen(InboxItem item, InboxMessageState state) => !state.done;

/// Whether [item] waits on the user: an unanswered question or blocker.
bool inboxItemNeedsReply(InboxItem item, InboxMessageState state) =>
    item.message.kind.awaitsUser && !state.replied && !state.done;

/// Unread messages outside Done, shown as the Inbox tab badge.
final inboxUnreadCountProvider = Provider<int>((ref) {
  final items = ref.watch(inboxCatalogProvider).items;
  final states = ref.watch(inboxStateProvider);
  var count = 0;
  for (final item in items) {
    final state = states[item.key] ?? InboxMessageState.initial;
    if (!state.read && !state.done) count++;
  }
  return count;
});
