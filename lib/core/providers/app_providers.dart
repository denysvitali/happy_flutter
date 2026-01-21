import 'package:riverpod/riverpod.dart';
import '../models/session.dart';
import '../models/machine.dart';
import '../models/settings.dart';
import '../models/auth.dart';
import '../api/websocket_client.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// App state providers

/// Authentication state provider
final authStateNotifierProvider = NotifierProvider<AuthStateNotifier, AuthState>(() {
  return AuthStateNotifier();
});

class AuthStateNotifier extends Notifier<AuthState> {
  final _authService = AuthService();

  @override
  AuthState build() {
    return AuthState.unauthenticated;
  }

  Future<void> checkAuth() async {
    state = AuthState.authenticating;
    try {
      final isAuth = await _authService.isAuthenticated();
      state = isAuth ? AuthState.authenticated : AuthState.unauthenticated;
    } catch (e) {
      state = AuthState.error;
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
final sessionsNotifierProvider = NotifierProvider<SessionsNotifier, Map<String, Session>>(() {
  return SessionsNotifier();
});

/// Machines provider
final machinesNotifierProvider = NotifierProvider<MachinesNotifier, Map<String, Machine>>(() {
  return MachinesNotifier();
});

/// Settings provider
final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(() {
  return SettingsNotifier();
});

/// WebSocket connection provider
final connectionNotifierProvider = NotifierProvider<ConnectionNotifier, ConnectionStatus>(() {
  return ConnectionNotifier();
});

/// Current session provider
final currentSessionNotifierProvider = NotifierProvider<CurrentSessionNotifier, Session?>(() {
  return CurrentSessionNotifier();
});
