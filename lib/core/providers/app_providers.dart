import 'package:riverpod/riverpod.dart';
import '../models/session.dart' hide TodoItem;
import '../models/machine.dart';
import '../models/settings.dart';
import '../models/auth.dart';
import '../models/profile.dart';
import '../models/friend.dart';
import '../models/artifact.dart';
import '../models/feed.dart';
import '../models/todo.dart';
import '../api/websocket_client.dart' show ConnectionStatus, WebSocketClient;
import '../services/auth_service.dart';
import '../services/storage_service.dart';

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
      if (isAuth && _pendingDeepLink != null) {
        await _handleDeepLink(_pendingDeepLink!);
        _pendingDeepLink = null;
      }
    } catch (e) {
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
      print('Failed to handle deep link: $e');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = AuthState.unauthenticated;
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
    final newState = Map<String, Session>.from(state);
    newState.remove(id);
    state = newState;
  }

  void setSessions(List<Session> sessions) {
    state = {
      for (final session in sessions) session.id: session,
    };
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
    state = {
      for (final machine in machines) machine.id: machine,
    };
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

  Future<void> updateSetting<T>(String key, T value) async {
    await _storage.updateSetting(key, value);
    state = _updateSetting(state, key, value);
  }

  Settings _updateSetting(dynamic settings, String key, dynamic value) {
    // Simple update for boolean/string values
    final json = settings.toJson();
    json[key] = value;
    return Settings.fromJson(json);
  }
}

/// WebSocket connection provider
class ConnectionNotifier extends Notifier<ConnectionStatus> {
  final _wsClient = WebSocketClient();

  @override
  ConnectionStatus build() => ConnectionStatus.disconnected;

  void connect(String serverUrl, String token) {
    _wsClient.connect(serverUrl: serverUrl, token: token);
  }

  void disconnect() {
    _wsClient.disconnect();
  }

  void listenToStatus() {
    _wsClient.onStatusChange((status) {
      state = status;
    });
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
final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, Settings>(() {
  return SettingsNotifier();
});

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
final profileNotifierProvider =
    NotifierProvider<ProfileNotifier, Profile?>(() {
  return ProfileNotifier();
});

class ProfileNotifier extends Notifier<Profile?> {
  final _storage = SettingsStorage();

  @override
  Profile? build() => null;

  Future<void> loadProfile() async {
    // Load profile from storage
    // This is a placeholder - actual implementation would call API
    state = null;
  }

  void updateProfile(Profile profile) {
    state = profile;
  }

  Future<void> updateAvatar(String avatarUrl) async {
    if (state != null) {
      state = state!.copyWith(avatarUrl: avatarUrl);
    }
  }

  Future<void> disconnectGitHub() async {
    if (state != null && state!.github != null) {
      state = state!.copyWith(github: null);
    }
  }
}

/// Per-session git status provider
final sessionGitStatusProvider =
    NotifierProvider<SessionGitStatusNotifier, Map<String, GitStatus>>(() {
  return SessionGitStatusNotifier();
});

class SessionGitStatusNotifier
    extends Notifier<Map<String, GitStatus>> {
  @override
  Map<String, GitStatus> build() => {};

  void updateGitStatus(String sessionId, GitStatus status) {
    state = {...state, sessionId: status};
  }

  void clearGitStatus(String sessionId) {
    final newState = Map<String, GitStatus>.from(state);
    newState.remove(sessionId);
    state = newState;
  }

  void clearAll() {
    state = {};
  }

  GitStatus? getGitStatus(String sessionId) => state[sessionId];
}

/// Artifacts provider
final artifactsNotifierProvider =
    NotifierProvider<ArtifactsNotifier, Map<String, Artifact>>(() {
  return ArtifactsNotifier();
});

class ArtifactsNotifier extends Notifier<Map<String, Artifact>> {
  @override
  Map<String, Artifact> build() => {};

  void addArtifact(Artifact artifact) {
    state = {...state, artifact.id: artifact};
  }

  void updateArtifact(String id, Artifact Function(Artifact) update) {
    if (state.containsKey(id)) {
      state = {...state, id: update(state[id]!)};
    }
  }

  void removeArtifact(String id) {
    final newState = Map<String, Artifact>.from(state);
    newState.remove(id);
    state = newState;
  }

  void setArtifacts(List<Artifact> artifacts) {
    state = {
      for (final artifact in artifacts) artifact.id: artifact,
    };
  }

  List<Artifact> getBySession(String sessionId) {
    return state.values
        .where((a) => a.sessionId == sessionId)
        .toList();
  }
}

/// Friends/social provider
final friendsNotifierProvider =
    NotifierProvider<FriendsNotifier, FriendsState>(() {
  return FriendsNotifier();
});

class FriendsNotifier extends Notifier<FriendsState> {
  @override
  FriendsState build() => FriendsState();

  void setFriends(List<UserProfile> friends) {
    state = state.copyWith(friends: friends);
  }

  void addFriend(UserProfile friend) {
    state = state.copyWith(
      friends: [...state.friends, friend],
    );
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
      pendingRequests:
          state.pendingRequests.where((r) => r.id != requestId).toList(),
    );
  }

  void clear() {
    state = FriendsState();
  }
}

class FriendsState {
  final List<UserProfile> friends;
  final List<FriendRequest> pendingRequests;

  FriendsState({
    this.friends = const [],
    this.pendingRequests = const [],
  });

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
      friends.where((f) => f.status == RelationshipStatus.friends).toList();

  List<FriendRequest> get incomingRequests => pendingRequests
      .where((r) => r.status == 'pending')
      .toList();
}

/// Feed/activity provider
final feedNotifierProvider =
    NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});

class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() => FeedState();

  void setFeedItems(List<FeedItem> items) {
    state = state.copyWith(items: items);
  }

  void addFeedItem(FeedItem item) {
    state = state.copyWith(
      items: [item, ...state.items],
    );
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
  final List<FeedItem> items;
  final List<AppNotification> notifications;

  FeedState({
    this.items = const [],
    this.notifications = const [],
  });

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

/// Todo list provider
final todoStateNotifierProvider =
    NotifierProvider<TodoStateNotifier, TodoListState>(() {
  return TodoStateNotifier();
});

class TodoStateNotifier extends Notifier<TodoListState> {
  @override
  TodoListState build() => TodoListState();

  void setTodoList(TodoList list) {
    final sessionId = list.sessionId;
    if (sessionId != null) {
      state = state.copyWith(
        lists: {...state.lists, sessionId: list},
      );
    }
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

  void updateTodo(String sessionId, String todoId,
      TodoItem Function(TodoItem) update) {
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
      final updatedItems =
          list.items.where((item) => item.id != todoId).toList();
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
    String? newParentId,
  }) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = list.items.map((item) {
        if (item.id == todoId) {
          return item.copyWith(
            order: newOrder,
            parentId: newParentId ?? item.parentId,
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
    final newLists = Map<String, TodoList>.from(state.lists);
    newLists.remove(sessionId);
    state = state.copyWith(lists: newLists);
  }

  void clear() {
    state = TodoListState();
  }
}

class TodoListState {
  final Map<String, TodoList> lists;

  TodoListState({this.lists = const {}});

  TodoListState copyWith({Map<String, TodoList>? lists}) {
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

