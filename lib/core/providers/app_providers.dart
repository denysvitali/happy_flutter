import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../api/socket_io_client.dart' as socket_io;
import '../api/websocket_client.dart' show ConnectionStatus;
import '../models/artifact.dart';
import '../models/auth.dart';
import '../models/feed.dart';
import '../models/friend.dart';
import '../models/machine.dart';
import '../models/profile.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/todo.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';


// Sentinel for distinguishing 'not provided' from null
const Object _unset = Object();

/// App state providers

/// Authentication state provider
final authStateNotifierProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(() {
      return AuthStateNotifier();
    });

class AuthStateNotifier extends Notifier<AuthState> {
  final _authService = AuthService();
  String? _pendingDeepLink;

  @override
  AuthState build() {
    return AuthState.unauthenticated;
  }

  Future<void> checkAuth() async {
    state = AuthState.authenticating;
    try {
      final isAuth = await _authService.isAuthenticated();
      state = isAuth ? AuthState.authenticated : AuthState.unauthenticated;
      if (isAuth) {
        // Set the token on ApiClient when authenticated
        final credentials = await TokenStorage().getCredentials();
        if (credentials != null) {
          ApiClient().updateToken(credentials.token);
          await syncRestore(credentials);
          ref.read(connectionNotifierProvider.notifier).listenToStatus();
          ref.read(sessionsNotifierProvider.notifier).loadFromSync();
          ref.read(machinesNotifierProvider.notifier).loadFromSync();
          ref.read(settingsNotifierProvider.notifier).loadFromSync();
          ref.read(profileNotifierProvider.notifier).loadFromSync();
          ref.read(friendsNotifierProvider.notifier).loadFromSync();
          ref.read(feedNotifierProvider.notifier).loadFromSync();
          ref.read(todoStateNotifierProvider.notifier).loadFromSync();
          await ref.read(profileNotifierProvider.notifier).refreshFromSync();
          await ref.read(friendsNotifierProvider.notifier).refreshFromSync();
          await ref.read(feedNotifierProvider.notifier).refreshFromSync();
          final profile = ref.read(profileNotifierProvider);
          if (profile != null) {
            Sentry.configureScope(
              (scope) => scope.setUser(SentryUser(id: profile.id)),
            );
          }
        }
        if (_pendingDeepLink != null) {
          await _handleDeepLink(_pendingDeepLink!);
          _pendingDeepLink = null;
        }
      }
    } catch (e, stack) {
      unawaited(Sentry.captureException(e, stackTrace: stack));
      state = AuthState.error;
    }
  }

  void handleDeepLink(String url) {
    if (state == AuthState.authenticated) {
      _handleDeepLink(url);
    } else {
      _pendingDeepLink = url;
    }
  }

  Future<void> _handleDeepLink(String url) async {
    try {
      await _authService.approveLinkingRequest(url);
    } catch (e) {
      debugPrint('Failed to handle deep link: $e');
    }
  }

  Future<void> signOut() async {
    await syncShutdown();
    await _authService.signOut();
    ref.read(sessionsNotifierProvider.notifier).clear();
    ref.read(machinesNotifierProvider.notifier).clear();
    ref.read(profileNotifierProvider.notifier).clear();
    ref.read(friendsNotifierProvider.notifier).clear();
    ref.read(feedNotifierProvider.notifier).clear();
    state = AuthState.unauthenticated;
    Sentry.configureScope((scope) => scope.setUser(null));
  }
}

/// Sessions provider
class SessionsNotifier extends Notifier<Map<String, Session>> {
  @override
  Map<String, Session> build() => {};

  void addSession(Session session) {
    state = {...state, session.id: session};
  }

  void updateSession(String id, Session Function(Session) update) {
    if (state.containsKey(id)) {
      state = {...state, id: update(state[id]!)};
    }
  }

  void removeSession(String id) {
    state = Map<String, Session>.from(state)..remove(id);
  }

  void setSessions(List<Session> sessions) {
    state = {for (final session in sessions) session.id: session};
  }

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = Map<String, Session>.from(sync.sessions);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.refreshSessions();
    loadFromSync();
  }

  void clear() {
    state = {};
  }

  Session? getSession(String id) => state[id];
}

/// Machines provider
class MachinesNotifier extends Notifier<Map<String, Machine>> {
  @override
  Map<String, Machine> build() => {};

  void addMachine(Machine machine) {
    state = {...state, machine.id: machine};
  }

  void updateMachine(String id, Machine Function(Machine) update) {
    if (state.containsKey(id)) {
      state = {...state, id: update(state[id]!)};
    }
  }

  void setMachines(List<Machine> machines) {
    state = {for (final machine in machines) machine.id: machine};
  }

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = Map<String, Machine>.from(sync.machines);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.refreshMachines();
    loadFromSync();
  }

  void clear() {
    state = {};
  }
}

/// Settings provider
class SettingsNotifier extends Notifier<Settings> {
  final _storage = SettingsStorage();

  @override
  Settings build() => Settings();

  Future<void> loadSettings() async {
    final settings = await _storage.getSettings();
    state = settings;
  }

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = sync.settingsSnapshot;
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.settingsSync.invalidateAndAwait();
    state = sync.settingsSnapshot;
  }

  Future<void> updateSetting<T>(String key, T value) async {
    await _storage.updateSetting(key, value);
    state = _updateSetting(state, key, value);
    if (sync.isInitialized) {
      await sync.applySettings({key: value});
    }
  }

  Settings _updateSetting(dynamic settings, String key, dynamic value) {
    // Directly update mutable field instead of JSON roundtrip
    final updated = settings as Settings;
    switch (key) {
      case 'schemaVersion':
        updated.schemaVersion = value as int;
      case 'themeMode':
        updated.themeMode = value as String;
      case 'viewInline':
        updated.viewInline = value as bool;
      case 'inferenceOpenAIKey':
        updated.inferenceOpenAIKey = value as String?;
      case 'expandTodos':
        updated.expandTodos = value as bool;
      case 'showLineNumbers':
        updated.showLineNumbers = value as bool;
      case 'showLineNumbersInToolViews':
        updated.showLineNumbersInToolViews = value as bool;
      case 'wrapLinesInDiffs':
        updated.wrapLinesInDiffs = value as bool;
      case 'analyticsOptOut':
        updated.analyticsOptOut = value as bool;
      case 'experiments':
        updated.experiments = value as bool;
      case 'markdownCopyV2':
        updated.markdownCopyV2 = value as bool;
      case 'useEnhancedSessionWizard':
        updated.useEnhancedSessionWizard = value as bool;
      case 'alwaysShowContextSize':
        updated.alwaysShowContextSize = value as bool;
      case 'agentInputEnterToSend':
        updated.agentInputEnterToSend = value as bool;
      case 'developerModeEnabled':
        updated.developerModeEnabled = value as bool;
      case 'avatarStyle':
        updated.avatarStyle = value as String;
      case 'showFlavorIcons':
        updated.showFlavorIcons = value as bool;
      case 'compactSessionView':
        updated.compactSessionView = value as bool;
      case 'hideInactiveSessions':
        updated.hideInactiveSessions = value as bool;
      case 'reviewPromptAnswered':
        updated.reviewPromptAnswered = value as bool;
      case 'reviewPromptLikedApp':
        updated.reviewPromptLikedApp = value as bool?;
      case 'ttsEnabled':
        updated.ttsEnabled = value as bool;
      case 'voiceAssistantLanguage':
        updated.voiceAssistantLanguage = value as String?;
      case 'preferredLanguage':
        updated.preferredLanguage = value as String?;
      case 'lastUsedAgent':
        updated.lastUsedAgent = value as String?;
      case 'lastUsedPermissionMode':
        updated.lastUsedPermissionMode = value as String?;
      case 'lastUsedModelMode':
        updated.lastUsedModelMode = value as String?;
      case 'lastUsedProfile':
        updated.lastUsedProfile = value as String?;
    }
    return updated;
  }
}

/// WebSocket connection provider
class ConnectionNotifier extends Notifier<ConnectionStatus> {
  void Function()? _unsubscribe;

  @override
  ConnectionStatus build() {
    ref.onDispose(() => _unsubscribe?.call());
    return _mapSocketStatus(sync.connectionStatus);
  }

  void connect(String serverUrl, String token) {
    socket_io.socketIoClient.connect(serverUrl: serverUrl, token: token);
  }

  void disconnect() {
    socket_io.socketIoClient.disconnect();
  }

  void listenToStatus() {
    _unsubscribe?.call();
    _unsubscribe = socket_io.socketIoClient.onStatusChange((status) {
      state = _mapSocketStatus(status);
    });
  }

  ConnectionStatus _mapSocketStatus(socket_io.ConnectionStatus status) {
    switch (status) {
      case socket_io.ConnectionStatus.connected:
        return ConnectionStatus.connected;
      case socket_io.ConnectionStatus.connecting:
        return ConnectionStatus.connecting;
      case socket_io.ConnectionStatus.error:
        return ConnectionStatus.error;
      case socket_io.ConnectionStatus.disconnected:
        return ConnectionStatus.disconnected;
    }
  }
}

/// Current session provider
class CurrentSessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => null;

  void setSession(Session? session) {
    state = session;
  }

  void updateDraft(String draft) {
    if (state != null) {
      state = state!.copyWith(draft: draft);
    }
  }

  void updatePermissionMode(String? mode) {
    if (state != null) {
      state = state!.copyWith(permissionMode: mode);
    }
  }

  void updateModelMode(String? mode) {
    if (state != null) {
      state = state!.copyWith(modelMode: mode);
    }
  }
}

/// Sessions provider
final sessionsNotifierProvider =
    NotifierProvider<SessionsNotifier, Map<String, Session>>(() {
      return SessionsNotifier();
    });

/// Machines provider
final machinesNotifierProvider =
    NotifierProvider<MachinesNotifier, Map<String, Machine>>(() {
      return MachinesNotifier();
    });

/// Settings provider
final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(
  () {
    return SettingsNotifier();
  },
);

/// WebSocket connection provider
final connectionNotifierProvider =
    NotifierProvider<ConnectionNotifier, ConnectionStatus>(() {
      return ConnectionNotifier();
    });

/// Current session provider
final currentSessionNotifierProvider =
    NotifierProvider<CurrentSessionNotifier, Session?>(() {
      return CurrentSessionNotifier();
    });

/// Profile provider
final profileNotifierProvider = NotifierProvider<ProfileNotifier, Profile?>(() {
  return ProfileNotifier();
});

class ProfileNotifier extends Notifier<Profile?> {
  @override
  Profile? build() => null;

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = sync.profile;
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.refreshProfile();
    loadFromSync();
  }

  void updateProfile(Profile profile) {
    state = profile;
  }

  Future<void> updateAvatar(String avatarUrl) async {
    if (state != null) {
      // Create a new ImageRef with minimal data from URL
      final newAvatar = ImageRef(
        width: state!.avatar?.width ?? 200,
        height: state!.avatar?.height ?? 200,
        thumbhash: state!.avatar?.thumbhash ?? '',
        path: state!.avatar?.path ?? '',
        url: avatarUrl,
      );
      state = state!.copyWith(avatar: newAvatar);
    }
  }

  Future<void> disconnectGitHub() async {
    if (state != null && state!.github != null) {
      state = state!.copyWith(clearGithub: true);
    }
  }

  void clear() {
    state = null;
  }
}

/// Per-session git status provider
final sessionGitStatusProvider =
    NotifierProvider<SessionGitStatusNotifier, Map<String, GitStatus>>(() {
      return SessionGitStatusNotifier();
    });

class SessionGitStatusNotifier extends Notifier<Map<String, GitStatus>> {
  @override
  Map<String, GitStatus> build() => {};

  void updateGitStatus(String sessionId, GitStatus status) {
    state = {...state, sessionId: status};
  }

  void clearGitStatus(String sessionId) {
    state = Map<String, GitStatus>.from(state)..remove(sessionId);
  }

  void clearAll() {
    state = {};
  }

  GitStatus? getGitStatus(String sessionId) => state[sessionId];
}

/// Artifacts provider
final artifactsNotifierProvider =
    NotifierProvider<ArtifactsNotifier, Map<String, DecryptedArtifact>>(
      () {
        return ArtifactsNotifier();
      },
    );

class ArtifactsNotifier
    extends Notifier<Map<String, DecryptedArtifact>> {
  @override
  Map<String, DecryptedArtifact> build() => {};

  void addArtifact(DecryptedArtifact artifact) {
    state = {...state, artifact.id: artifact};
  }

  void updateArtifact(
    String id,
    DecryptedArtifact Function(DecryptedArtifact) update,
  ) {
    if (state.containsKey(id)) {
      state = {...state, id: update(state[id]!)};
    }
  }

  void removeArtifact(String id) {
    state = Map<String, DecryptedArtifact>.from(state)..remove(id);
  }

  void setArtifacts(List<DecryptedArtifact> artifacts) {
    state = {for (final artifact in artifacts) artifact.id: artifact};
  }

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = {for (final a in sync.artifacts) a.id: a};
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.artifactsSync.invalidateAndAwait();
    loadFromSync();
  }

  // NOTE: Cannot filter by sessionId without decrypting headers first
  // The sessionId is stored in the encrypted header, not on the Artifact model
  //
  // List<DecryptedArtifact> getBySession(String sessionId) {
  //   return state.values
  //       .where((a) => a.sessions?.contains(sessionId) ?? false)
  //       .toList();
  // }
}

/// Friends/social provider
final friendsNotifierProvider = NotifierProvider<FriendsNotifier, FriendsState>(
  () {
    return FriendsNotifier();
  },
);

class FriendsNotifier extends Notifier<FriendsState> {
  @override
  FriendsState build() => FriendsState();

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = state.copyWith(
      friends: sync.friends,
      pendingRequests: sync.friendRequests,
    );
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.refreshFriends();
    loadFromSync();
  }

  void setFriends(List<UserProfile> friends) {
    state = state.copyWith(friends: friends);
  }

  void addFriend(UserProfile friend) {
    state = state.copyWith(friends: [...state.friends, friend]);
  }

  void removeFriend(String userId) {
    state = state.copyWith(
      friends: state.friends.where((f) => f.id != userId).toList(),
    );
  }

  void updateFriendStatus(String userId, RelationshipStatus status) {
    state = state.copyWith(
      friends: state.friends.map((f) {
        if (f.id == userId) {
          return f.copyWith(status: status);
        }
        return f;
      }).toList(),
    );
  }

  void setPendingRequests(List<FriendRequest> requests) {
    state = state.copyWith(pendingRequests: requests);
  }

  void addPendingRequest(FriendRequest request) {
    state = state.copyWith(
      pendingRequests: [...state.pendingRequests, request],
    );
  }

  void removePendingRequest(String requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.id != requestId)
          .toList(),
    );
  }

  void clear() {
    state = FriendsState();
  }
}

class FriendsState {

  FriendsState({this.friends = const [], this.pendingRequests = const []});
  final List<UserProfile> friends;
  final List<FriendRequest> pendingRequests;

  FriendsState copyWith({
    List<UserProfile>? friends,
    List<FriendRequest>? pendingRequests,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
    );
  }

  List<UserProfile> get friendList =>
      friends.where((f) => f.status == RelationshipStatus.friend).toList();

  List<FriendRequest> get incomingRequests =>
      pendingRequests.where((r) => r.status == 'pending').toList();
}

/// Feed/activity provider
final feedNotifierProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});

class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() => FeedState();

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    state = state.copyWith(items: sync.feedItems);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.refreshFeed();
    loadFromSync();
  }

  void setFeedItems(List<FeedItem> items) {
    state = state.copyWith(items: items);
  }

  void addFeedItem(FeedItem item) {
    state = state.copyWith(items: [item, ...state.items]);
  }

  void markAsRead(String itemId) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(read: true);
        }
        return item;
      }).toList(),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      items: state.items.map((item) => item.copyWith(read: true)).toList(),
    );
  }

  void removeFeedItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != itemId).toList(),
    );
  }

  void setNotifications(List<AppNotification> notifications) {
    state = state.copyWith(notifications: notifications);
  }

  void addNotification(AppNotification notification) {
    state = state.copyWith(
      notifications: [notification, ...state.notifications],
    );
  }

  void dismissNotification(String id) {
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) {
          return n.copyWith(dismissed: true);
        }
        return n;
      }).toList(),
    );
  }

  void clear() {
    state = FeedState();
  }
}

class FeedState {

  FeedState({this.items = const [], this.notifications = const []});
  final List<FeedItem> items;
  final List<AppNotification> notifications;

  FeedState copyWith({
    List<FeedItem>? items,
    List<AppNotification>? notifications,
  }) {
    return FeedState(
      items: items ?? this.items,
      notifications: notifications ?? this.notifications,
    );
  }

  int get unreadCount => items.where((i) => !i.read).length;
  int get unreadNotifications =>
      notifications.where((n) => !n.dismissed && !n.read).length;
}

/// Task list provider
final todoStateNotifierProvider =
    NotifierProvider<TodoStateNotifier, TodoListState>(() {
      return TodoStateNotifier();
    });

class TodoStateNotifier extends Notifier<TodoListState> {
  @override
  TodoListState build() => TodoListState();

  void loadFromSync() {
    if (!sync.isInitialized) {
      return;
    }
    final mapped = <String?, TodoList>{};
    for (final entry in sync.todoLists.entries) {
      mapped[entry.key] = entry.value;
    }
    state = TodoListState(lists: mapped);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    await sync.todosSync.invalidateAndAwait();
    loadFromSync();
  }

  void setTodoList(TodoList list) {
    state = state.copyWith(
      lists: {...state.lists, list.sessionId: list},
    );
  }

  void addTodo(String sessionId, TodoItem item) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = [...list.items, item];
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(
        lists: {...state.lists, sessionId: updatedList},
      );
    }
  }

  void updateTodo(
    String sessionId,
    String todoId,
    TodoItem Function(TodoItem) update,
  ) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = list.items.map((item) {
        if (item.id == todoId) {
          return update(item);
        }
        return item;
      }).toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(
        lists: {...state.lists, sessionId: updatedList},
      );
    }
  }

  void removeTodo(String sessionId, String todoId) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = list.items
          .where((item) => item.id != todoId)
          .toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(
        lists: {...state.lists, sessionId: updatedList},
      );
    }
  }

  void reorderTodos(
    String sessionId,
    String todoId,
    int newOrder, {
    Object? newParentId = _unset,
  }) {
    final list = state.lists[sessionId];
    if (list != null) {
      final parentChanged = !identical(newParentId, _unset);
      final resolvedParentId = parentChanged
          ? newParentId as String?
          : null;
      final updatedItems = list.items.map((item) {
        if (item.id == todoId) {
          return item.copyWith(
            order: newOrder,
            clearParentId: parentChanged && resolvedParentId == null,
            parentId: parentChanged && resolvedParentId != null
                ? resolvedParentId
                : null,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
        return item;
      }).toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(
        lists: {...state.lists, sessionId: updatedList},
      );
    }
  }

  void clearSessionTodos(String sessionId) {
    state = state.copyWith(
      lists: Map<String?, TodoList>.from(state.lists)..remove(sessionId),
    );
  }

  void clear() {
    state = TodoListState();
  }
}

class TodoListState {
  TodoListState({this.lists = const {}});
  final Map<String?, TodoList> lists;

  TodoListState copyWith({Map<String?, TodoList>? lists}) {
    return TodoListState(lists: lists ?? this.lists);
  }

  TodoList? getGlobalList() => lists[null];

  List<TodoItem> get allTodos {
    return lists.values.expand((list) => list.items).toList();
  }

  int get totalCount => allTodos.length;
  int get completedCount =>
      allTodos.where((t) => t.status == TodoState.completed).length;
}
