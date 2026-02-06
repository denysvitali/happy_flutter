import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/socket_io_client.dart';
import '../api/api_client.dart';
import '../api/kv_api.dart';
import '../models/auth.dart';
import '../encryption/encryption_manager.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';
import '../services/server_config.dart';
import '../encryption/base64.dart';
import '../encryption/encryption_cache.dart';
import '../models/api_update.dart';
import '../models/session.dart';
import '../models/machine.dart';
import '../models/settings.dart';
import '../models/profile.dart';
import '../models/artifact.dart';
import '../models/friend.dart';
import '../models/feed.dart';
import '../models/todo.dart';
import '../utils/invalidate_sync.dart';
import '../utils/parse_token.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global singleton instance
class Sync {
  static final Sync _instance = Sync._();
  factory Sync() => _instance;
  Sync._();

  // Constants
  static const int SESSION_READY_TIMEOUT_MS = 10000;

  // Core dependencies
  late Encryption encryption;
  late String serverID;
  late String anonID;
  late AuthCredentials credentials;
  final EncryptionCache encryptionCache = EncryptionCache();

  // Data key storage
  final Map<String, Uint8List> _sessionDataKeys = {};
  final Map<String, Uint8List> _machineDataKeys = {};
  final Map<String, Uint8List> _artifactDataKeys = {};

  // Sync managers
  late InvalidateSync sessionsSync;
  final Map<String, InvalidateSync> messagesSync = {};
  final Map<String, Set<String>> sessionReceivedMessages = {};
  late InvalidateSync settingsSync;
  late InvalidateSync profileSync;
  late InvalidateSync purchasesSync;
  late InvalidateSync machinesSync;
  late InvalidateSync pushTokenSync;
  late InvalidateSync nativeUpdateSync;
  late InvalidateSync artifactsSync;
  late InvalidateSync friendsSync;
  late InvalidateSync friendRequestsSync;
  late InvalidateSync feedSync;
  late InvalidateSync todosSync;

  // State tracking
  bool revenueCatInitialized = false;
  bool isInitialized = false;

  // Recalculation locking
  int recalculationLockCount = 0;
  int lastRecalculationTime = 0;

  // Pending settings
  Map<String, dynamic> pendingSettings = {};
  final Map<String?, TodoList> _todoLists = <String?, TodoList>{};

  Map<String?, TodoList> get todoLists => Map.unmodifiable(_todoLists);

  /// Initialize sync with credentials and encryption
  Future<void> create(AuthCredentials credentials, Encryption encryption) async {
    if (isInitialized) {
      debugPrint('Sync already initialized');
      return;
    }

    this.credentials = credentials;
    this.encryption = encryption;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    await _init();

    // Await initial syncs
    await settingsSync.awaitQueue();
    await profileSync.awaitQueue();
    await purchasesSync.awaitQueue();

    isInitialized = true;
  }

  /// Restore sync state from disk (app restart)
  Future<void> restore(AuthCredentials credentials, Encryption encryption) async {
    if (isInitialized) {
      debugPrint('Sync already initialized');
      return;
    }

    this.credentials = credentials;
    this.encryption = encryption;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    await _init();

    isInitialized = true;
  }

  /// Internal initialization
  Future<void> _init() async {
    // Initialize sync managers
    sessionsSync = InvalidateSync(fetchSessions);
    settingsSync = InvalidateSync(syncSettings);
    profileSync = InvalidateSync(fetchProfile);
    purchasesSync = InvalidateSync(syncPurchases);
    machinesSync = InvalidateSync(fetchMachines);
    pushTokenSync = InvalidateSync(syncPushToken);
    nativeUpdateSync = InvalidateSync(fetchNativeUpdate);
    artifactsSync = InvalidateSync(fetchArtifactsList);
    friendsSync = InvalidateSync(fetchFriends);
    friendRequestsSync = InvalidateSync(fetchFriendRequests);
    feedSync = InvalidateSync(fetchFeed);
    todosSync = InvalidateSync(fetchTodos);

    // Setup socket connection
    final serverUrl = getServerUrl();
    socketIoClient.connect(
      serverUrl: serverUrl,
      token: credentials.token,
      clientType: 'user-scoped',
    );

    // Subscribe to updates
    subscribeToUpdates();

    // Invalidate all syncs
    _invalidateAllSyncs();

    // Wait for sessions and machines to load before marking as ready
    await Future.wait([
      sessionsSync.awaitQueue(),
      machinesSync.awaitQueue(),
    ]);

    // TODO: Implement ready state notification
  }

  /// Invalidate all sync managers
  void _invalidateAllSyncs() {
    sessionsSync.invalidate();
    settingsSync.invalidate();
    profileSync.invalidate();
    purchasesSync.invalidate();
    machinesSync.invalidate();
    pushTokenSync.invalidate();
    nativeUpdateSync.invalidate();
    friendsSync.invalidate();
    friendRequestsSync.invalidate();
    artifactsSync.invalidate();
    feedSync.invalidate();
    todosSync.invalidate();
  }

  /// Subscribe to socket updates
  void subscribeToUpdates() {
    socketIoClient.onMessage('update', handleUpdate);
    socketIoClient.onMessage('ephemeral', handleEphemeralUpdate);

    socketIoClient.onReconnected(() {
      debugPrint('Socket reconnected');
      _invalidateAllSyncs();
    });

    socketIoClient.onStatusChange((status) {
      // TODO: Update connection status in state
    });
  }

  /// Handle incoming updates
  void handleUpdate(dynamic data) {
    try {
      final update = ApiUpdate.fromJson(data as Map<String, dynamic>);

      switch (update.type) {
        case 'new-message':
          _handleNewMessage(update.data);
          break;
        case 'new-session':
          _handleNewSession(update.data);
          break;
        case 'delete-session':
          _handleDeleteSession(update.data);
          break;
        case 'update-session':
          _handleUpdateSession(update.data);
          break;
        case 'update-account':
          _handleUpdateAccount(update.data);
          break;
        case 'update-machine':
          _handleUpdateMachine(update.data);
          break;
        case 'relationship-updated':
          _handleRelationshipUpdated(update.data);
          break;
        case 'new-artifact':
          _handleNewArtifact(update.data);
          break;
        case 'update-artifact':
          _handleUpdateArtifact(update.data);
          break;
        case 'delete-artifact':
          _handleDeleteArtifact(update.data);
          break;
        case 'new-feed-post':
          _handleNewFeedPost(update.data);
          break;
        case 'kv-batch-update':
          _handleKvBatchUpdate(update.data);
          break;
      }
    } catch (error) {
      debugPrint('Failed to handle update: $error');
    }
  }

  /// Handle new message update
  void _handleNewMessage(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
    sessionsSync.invalidate();
    debugPrint(
      'New message received${sessionId != null ? ': $sessionId' : ''}',
    );
  }

  /// Handle new session update
  void _handleNewSession(Map<String, dynamic> data) {
    debugPrint('New session received');
    sessionsSync.invalidate();
  }

  /// Handle session deletion
  void _handleDeleteSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null) {
      messagesSync.remove(sessionId)?.dispose();
      sessionReceivedMessages.remove(sessionId);
    }
    sessionsSync.invalidate();
    debugPrint(
      'Session deletion received${sessionId != null ? ': $sessionId' : ''}',
    );
  }

  /// Handle session update
  void _handleUpdateSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String?;
    sessionsSync.invalidate();
    if (sessionId != null && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
    debugPrint(
      'Session update received${sessionId != null ? ': $sessionId' : ''}',
    );
  }

  /// Handle account update
  void _handleUpdateAccount(Map<String, dynamic> data) {
    debugPrint('Account update received');
    profileSync.invalidate();
    settingsSync.invalidate();
  }

  /// Handle machine update
  void _handleUpdateMachine(Map<String, dynamic> data) {
    debugPrint('Machine update received');
    machinesSync.invalidate();
  }

  /// Handle relationship update
  void _handleRelationshipUpdated(Map<String, dynamic> data) {
    debugPrint('Relationship update received');
    friendsSync.invalidate();
    friendRequestsSync.invalidate();
    feedSync.invalidate();
  }

  /// Handle new artifact update
  void _handleNewArtifact(Map<String, dynamic> data) {
    debugPrint('New artifact received');
    artifactsSync.invalidate();
  }

  /// Handle artifact update
  void _handleUpdateArtifact(Map<String, dynamic> data) {
    debugPrint('Artifact update received');
    artifactsSync.invalidate();
  }

  /// Handle artifact deletion
  void _handleDeleteArtifact(Map<String, dynamic> data) {
    debugPrint('Artifact deletion received');
    artifactsSync.invalidate();
  }

  /// Handle new feed post
  void _handleNewFeedPost(Map<String, dynamic> data) {
    debugPrint('New feed post received');
    feedSync.invalidate();
  }

  /// Handle KV batch update (for todos)
  void _handleKvBatchUpdate(Map<String, dynamic> data) {
    final changes = data['changes'];
    if (changes is List &&
        changes.any((change) =>
            change is Map<String, dynamic> &&
            (change['key'] as String?)?.startsWith('todo.') == true)) {
      todosSync.invalidate();
      debugPrint('KV batch update received (todos)');
      return;
    }

    final serialized = jsonEncode(data).toLowerCase();
    if (serialized.contains('todo')) {
      todosSync.invalidate();
      debugPrint('KV batch update received (todos-fallback)');
      return;
    }

    debugPrint('KV batch update received (non-todo)');
  }

  /// Handle ephemeral updates
  void handleEphemeralUpdate(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return;
    }

    final sessionId = data['sid'] as String?;
    if (sessionId == null) {
      return;
    }

    if (messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Fetch sessions from server
  Future<void> fetchSessions() async {
    debugPrint('Fetching sessions...');

    try {
      final apiClient = ApiClient();
      
      final response = await apiClient.get('/v1/sessions');
      
      if (apiClient.isSuccess(response)) {
        final data = response.data;
        final sessions = data['sessions'] as List;

        // Initialize session encryptions
        final sessionKeys = <String, Uint8List?>{};
        for (final session in sessions) {
          final sessionId = session['id'] as String;
          final dataEncryptionKey = session['dataEncryptionKey'] as String?;

          if (dataEncryptionKey != null) {
            final decryptedKey = await encryption.decryptEncryptionKey(dataEncryptionKey);
            if (decryptedKey != null) {
              sessionKeys[sessionId] = decryptedKey;
              _sessionDataKeys[sessionId] = decryptedKey;
            }
          } else {
            sessionKeys[sessionId] = null;
          }
        }

        await encryption.initializeSessions(sessionKeys);

        // Decrypt sessions
        final decryptedSessions = <Session>[];
        for (final session in sessions) {
          final sessionId = session['id'] as String;
          final sessionEncryption = encryption.getSessionEncryption(sessionId);

          if (sessionEncryption != null) {
            try {
              // Decrypt metadata
              final metadata = await sessionEncryption.decryptMetadata(
                session['metadataVersion'] as int,
                session['metadata'] as String,
              );

              // Decrypt agent state
              final agentState = await sessionEncryption.decryptAgentState(
                session['agentStateVersion'] as int,
                session['agentState'] as String?,
              );

              // Create session object
              final processedSession = Session(
                id: sessionId,
                seq: session['seq'] as int,
                createdAt: session['createdAt'] as int,
                updatedAt: session['updatedAt'] as int,
                active: session['active'] as bool,
                activeAt: session['activeAt'] as int,
                metadata: metadata != null ? Metadata.fromJson(metadata) : null,
                metadataVersion: session['metadataVersion'] as int,
                agentState: agentState != null ? AgentState.fromJson(agentState) : null,
                agentStateVersion: session['agentStateVersion'] as int,
                thinking: false,
                thinkingAt: null,
                presence: 'online',
              );

              decryptedSessions.add(processedSession);
            } catch (error) {
              debugPrint('Failed to decrypt session $sessionId: $error');
            }
          }
        }

        // TODO: Apply sessions to storage/state
        debugPrint('Fetched and decrypted ${decryptedSessions.length} sessions');
      } else {
        debugPrint('Failed to fetch sessions: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching sessions: $error');
    }
  }

  /// Fetch machines from server
  Future<void> fetchMachines() async {
    debugPrint('Fetching machines...');

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/machines');

      if (apiClient.isSuccess(response)) {
        final data = response.data as List;

        // Initialize machine encryptions
        final machineKeys = <String, Uint8List?>{};
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final dataEncryptionKey = machine['dataEncryptionKey'] as String?;

          if (dataEncryptionKey != null) {
            final decryptedKey = await encryption.decryptEncryptionKey(dataEncryptionKey);
            if (decryptedKey != null) {
              machineKeys[machineId] = decryptedKey;
              _machineDataKeys[machineId] = decryptedKey;
            }
          } else {
            machineKeys[machineId] = null;
          }
        }

        await encryption.initializeMachines(machineKeys);

        // Decrypt machines
        final decryptedMachines = <Machine>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final machineEncryption = encryption.getMachineEncryption(machineId);

          if (machineEncryption != null) {
            try {
              final metadata = await machineEncryption.decryptMetadata(
                machine['metadataVersion'] as int,
                machine['metadata'] as String,
              );

              final daemonState = await machineEncryption.decryptDaemonState(
                machine['daemonStateVersion'] as int,
                machine['daemonState'] as String?,
              );

              final processedMachine = Machine(
                id: machineId,
                seq: machine['seq'] as int,
                createdAt: machine['createdAt'] as int,
                updatedAt: machine['updatedAt'] as int,
                active: machine['active'] as bool,
                activeAt: machine['activeAt'] as int,
                metadata: metadata != null ? MachineMetadata.fromJson(metadata) : null,
                metadataVersion: machine['metadataVersion'] as int,
                daemonState: daemonState,
                daemonStateVersion: machine['daemonStateVersion'] as int,
              );

              decryptedMachines.add(processedMachine);
            } catch (error) {
              debugPrint('Failed to decrypt machine $machineId: $error');
            }
          }
        }

        // TODO: Apply machines to storage/state
        debugPrint('Fetched and decrypted ${decryptedMachines.length} machines');
      } else {
        debugPrint('Failed to fetch machines: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching machines: $error');
    }
  }

  /// Fetch artifacts list from server
  Future<void> fetchArtifactsList() async {
    debugPrint('Fetching artifacts...');

    // TODO: Implement artifact fetching
  }

  /// Fetch friends list from server
  Future<void> fetchFriends() async {
    debugPrint('Fetching friends...');

    // TODO: Implement friends fetching
  }

  /// Fetch friend requests from server (backward compatibility)
  Future<void> fetchFriendRequests() async {
    debugPrint('Fetching friend requests (handled by fetchFriends)');
  }

  /// Fetch feed items from server
  Future<void> fetchFeed() async {
    debugPrint('Fetching feed...');

    // TODO: Implement feed fetching
  }

  /// Fetch todos from server
  Future<void> fetchTodos() async {
    debugPrint('Fetching todos...');
    try {
      final items = await KvApi().getByPrefix('todo.', limit: 1000);
      final decryptedByKey = <String, Map<String, dynamic>>{};

      for (final item in items) {
        try {
          final decrypted = await encryption.decryptRaw(item.value);
          if (decrypted is Map<String, dynamic>) {
            decryptedByKey[item.key] = decrypted;
          }
        } catch (error) {
          debugPrint('Failed to decrypt todo item ${item.key}: $error');
        }
      }

      final parsedTodoLists = parseTodoListsFromDecryptedKv(decryptedByKey);
      _todoLists
        ..clear()
        ..addAll(parsedTodoLists);

      final totalItems = parsedTodoLists.values
          .expand((list) => list.items)
          .toSet()
          .length;
      debugPrint(
        'Fetched todos: ${parsedTodoLists.length} list(s), $totalItems item(s)',
      );
    } catch (error) {
      debugPrint('Failed to fetch todos: $error');
    }
  }

  @visibleForTesting
  Map<String?, TodoList> parseTodoListsFromDecryptedKv(
    Map<String, Map<String, dynamic>> decryptedByKey,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final todosById = <String, TodoItem>{};
    List<String> undoneOrder = <String>[];
    List<String> doneOrder = <String>[];

    for (final entry in decryptedByKey.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'todo.index') {
        final rawUndone = value['undoneOrder'];
        if (rawUndone is List) {
          undoneOrder = rawUndone.whereType<String>().toList();
        }

        final rawCompleted = value['completedOrder'];
        if (rawCompleted is List) {
          doneOrder = rawCompleted.whereType<String>().toList();
        } else {
          final rawDone = value['doneOrder'];
          if (rawDone is List) {
            doneOrder = rawDone.whereType<String>().toList();
          }
        }
        continue;
      }

      if (!key.startsWith('todo.')) {
        continue;
      }

      final todoId = key.substring(5);
      if (todoId.isEmpty || todoId == 'index') {
        continue;
      }

      final mapped = _mapDecryptedTodoItem(
        todoId,
        value,
        createdFallbackAt: now,
      );
      todosById[todoId] = mapped;
    }

    undoneOrder = undoneOrder.where(todosById.containsKey).toList();
    doneOrder = doneOrder.where(todosById.containsKey).toList();

    final orderedIds = <String>{...undoneOrder, ...doneOrder};
    for (final entry in todosById.entries) {
      if (!orderedIds.contains(entry.key)) {
        if (entry.value.status == TodoState.completed ||
            entry.value.status == TodoState.canceled) {
          doneOrder.add(entry.key);
        } else {
          undoneOrder.add(entry.key);
        }
      }
    }

    final allOrderedIds = <String>[...undoneOrder, ...doneOrder];
    final grouped = <String?, List<TodoItem>>{null: <TodoItem>[]};
    var order = 0;

    for (final todoId in allOrderedIds) {
      final base = todosById[todoId];
      if (base == null) {
        continue;
      }

      final item = base.copyWith(order: order++);
      grouped[null]!.add(item);

      final sessionId = item.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        grouped.putIfAbsent(sessionId, () => <TodoItem>[]).add(item);
      }
    }

    final result = <String?, TodoList>{};
    for (final entry in grouped.entries) {
      result[entry.key] = TodoList(
        sessionId: entry.key,
        items: entry.value,
        updatedAt: now,
      );
    }
    return result;
  }

  TodoItem _mapDecryptedTodoItem(
    String todoId,
    Map<String, dynamic> raw, {
    required int createdFallbackAt,
  }) {
    final content = (raw['content'] as String?) ??
        (raw['title'] as String?) ??
        '';

    final rawStatus = raw['status'];
    final status = _mapTodoStatus(rawStatus, raw['done']);

    final linkedSessions = raw['linkedSessions'];
    String? sessionId = raw['sessionId'] as String?;
    if ((sessionId == null || sessionId.isEmpty) &&
        linkedSessions is Map<String, dynamic> &&
        linkedSessions.isNotEmpty) {
      sessionId = linkedSessions.keys.first;
    }

    final dependenciesRaw = raw['dependencies'];
    final dependencies = dependenciesRaw is List
        ? dependenciesRaw.whereType<String>().toList()
        : <String>[];

    return TodoItem(
      id: (raw['id'] as String?) ?? todoId,
      content: content,
      status: status,
      priority: (raw['priority'] as String?) ?? 'medium',
      order: 0,
      parentId: raw['parentId'] as String?,
      dependencies: dependencies,
      dueAt: _asInt(raw['dueAt']),
      createdAt: _asInt(raw['createdAt']) ?? createdFallbackAt,
      updatedAt: _asInt(raw['updatedAt']) ?? createdFallbackAt,
      sessionId: sessionId,
      completedAt: _asInt(raw['completedAt']),
    );
  }

  TodoState _mapTodoStatus(dynamic rawStatus, dynamic rawDone) {
    if (rawStatus is String) {
      return TodoState.fromString(rawStatus);
    }

    if (rawDone is bool) {
      return rawDone ? TodoState.completed : TodoState.pending;
    }

    return TodoState.pending;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  /// Sync settings with server
  Future<void> syncSettings() async {
    debugPrint('Syncing settings...');

    try {
      final apiClient = ApiClient();

      // Apply pending settings
      if (pendingSettings.isNotEmpty) {
        // TODO: Implement pending settings sync with versioning
      }

      // Fetch latest settings
      final response = await apiClient.get('/v1/account/settings');

      if (apiClient.isSuccess(response)) {
        final data = response.data;
        final encryptedSettings = data['settings'] as String?;

        if (encryptedSettings != null) {
          final decrypted = await encryption.decryptRaw(encryptedSettings);
          if (decrypted != null) {
            final settings = Settings.fromJson(decrypted);
            final settingsVersion = data['settingsVersion'] as int;

            // TODO: Apply settings to state with version
          }
        }
      } else {
        debugPrint('Failed to fetch settings: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error syncing settings: $error');
    }
  }

  /// Sync purchases with RevenueCat
  Future<void> syncPurchases() async {
    debugPrint('Syncing purchases...');

    // TODO: Implement RevenueCat integration
  }

  /// Fetch profile from server
  Future<void> fetchProfile() async {
    debugPrint('Fetching profile...');

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get('/v1/account/profile');

      if (apiClient.isSuccess(response)) {
        final data = response.data;
        final profile = Profile.fromJson(data);

        // TODO: Apply profile to state
      } else {
        debugPrint('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching profile: $error');
    }
  }

  /// Fetch native app update status
  Future<void> fetchNativeUpdate() async {
    debugPrint('Fetching native update...');

    // TODO: Implement native update check
  }

  /// Register or refresh device push token
  Future<void> syncPushToken() async {
    debugPrint('Syncing push token...');
    // TODO: Wire Firebase/APNs token provider and call PushApi.registerToken
  }

  /// Refresh machines from server
  Future<void> refreshMachines() async {
    await fetchMachines();
  }

  /// Refresh sessions from server
  Future<void> refreshSessions() async {
    await sessionsSync.invalidateAndAwait();
  }

  /// Send message to session
  Future<void> sendMessage(String sessionId, String text, {String? displayText}) async {
    // TODO: Implement message sending
  }

  /// Apply settings delta
  Future<void> applySettings(Map<String, dynamic> delta) async {
    // TODO: Implement settings application
  }

  /// Refresh purchases data
  Future<void> refreshPurchases() async {
    purchasesSync.invalidate();
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await profileSync.invalidateAndAwait();
  }

  /// Get authentication credentials
  AuthCredentials getCredentials() {
    return credentials;
  }

  /// On session visible handler
  void onSessionVisible(String sessionId) {
    if (!messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] = InvalidateSync(() => fetchMessages(sessionId));
    }
    messagesSync[sessionId]?.invalidate();
  }

  /// Fetch messages for a session
  Future<void> fetchMessages(String sessionId) async {
    debugPrint('Fetching messages for session: $sessionId');

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      throw StateError('Session encryption not initialized for $sessionId');
    }

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/sessions/$sessionId/messages');

      if (apiClient.isSuccess(response)) {
        final data = response.data;
        final messages = data['messages'] as List;

        // TODO: Decrypt and process messages
      } else {
        debugPrint('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching messages: $error');
    }
  }

  /// Wait for agent to be ready
  Future<bool> waitForAgentReady(String sessionId, [int timeoutMs = SESSION_READY_TIMEOUT_MS]) async {
    // TODO: Implement agent ready waiting
    return Future.value(true);
  }
}

// Global singleton instance
final sync = Sync();

/// Initialize sync engine
Future<void> syncCreate(AuthCredentials credentials) async {
  if (sync.isInitialized) {
    debugPrint('Sync already initialized');
    return;
  }

  final secretKey = Base64Utils.decode(credentials.secret, Encoding.base64url);
  if (secretKey.length != 32) {
    throw StateError('Invalid secret key length: ${secretKey.length}, expected 32');
  }

  final encryption = await Encryption.create(secretKey);
  await sync.create(credentials, encryption);
}

/// Restore sync engine from disk
Future<void> syncRestore(AuthCredentials credentials) async {
  if (sync.isInitialized) {
    debugPrint('Sync already initialized');
    return;
  }

  final secretKey = Base64Utils.decode(credentials.secret, Encoding.base64url);
  if (secretKey.length != 32) {
    throw StateError('Invalid secret key length: ${secretKey.length}, expected 32');
  }

  final encryption = await Encryption.create(secretKey);
  await sync.restore(credentials, encryption);
}
