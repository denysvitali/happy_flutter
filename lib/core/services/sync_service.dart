import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/socket_io_client.dart';
import '../api/api_client.dart';
import '../api/kv_api.dart';
import '../api/push_api.dart';
import '../models/auth.dart';
import '../encryption/encryption_manager.dart';
import '../encryption/artifact_encryption.dart';
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
import '../models/purchases.dart';
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
  static const String _appendSystemPrompt = '''
# Options

You have a way to give a user a easy way to answer your questions if you know
possible answers. To provide this, you need to output in your final response
an XML:

<options>
    <option>Option 1</option>
    ...
    <option>Option N</option>
</options>

You must output this in the very end of your response, not inside of any
other text. Do not wrap it into a codeblock. Always dedicate "<options>" and
"</options>" to a dedicated line. Never output anything like "custom", user
always have an option to send a custom message. Do not enumerate options in
both text and options block.
Always prefer to use the options mode to the text mode. Try to keep options
minimal, better to clarify in a next steps.

# Plan mode with options

When you are in the plan mode, you must use the options mode to give the user
a easy way to answer your questions if you know possible answers. Do not
assume what is needed, when there is discrepancy between what you need and
what you have, you must use the options mode.
''';

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
  bool _isReady = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _registeredPushToken;
  String? _nativeUpdateUrl;

  // Recalculation locking
  int recalculationLockCount = 0;
  int lastRecalculationTime = 0;

  // Pending settings
  Map<String, dynamic> pendingSettings = {};
  final Map<String?, TodoList> _todoLists = <String?, TodoList>{};
  final List<UserProfile> _friends = <UserProfile>[];
  final List<FriendRequest> _friendRequests = <FriendRequest>[];
  final List<FeedItem> _feedItems = <FeedItem>[];
  final List<DecryptedArtifact> _artifacts = <DecryptedArtifact>[];
  final Map<String, List<Map<String, dynamic>>> _sessionMessages = {};
  Settings _settingsSnapshot = Settings();
  int _settingsVersion = 0;
  Purchases _purchases = Purchases.defaults;
  final Map<String, Session> _sessions = <String, Session>{};
  final Map<String, Machine> _machines = <String, Machine>{};
  Profile? _profile;

  Map<String?, TodoList> get todoLists => Map.unmodifiable(_todoLists);
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get friendRequests => List.unmodifiable(_friendRequests);
  List<FeedItem> get feedItems => List.unmodifiable(_feedItems);
  List<DecryptedArtifact> get artifacts => List.unmodifiable(_artifacts);
  Settings get settingsSnapshot => _settingsSnapshot;
  int get settingsVersion => _settingsVersion;
  Purchases get purchases => _purchases;
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);
  Map<String, Machine> get machines => Map.unmodifiable(_machines);
  Profile? get profile => _profile;
  bool get isReady => _isReady;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get nativeUpdateUrl => _nativeUpdateUrl;
  bool get hasNativeUpdate => _nativeUpdateUrl != null;
  Map<String, List<Map<String, dynamic>>> get sessionMessages =>
      Map.unmodifiable(
        _sessionMessages.map(
          (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
        ),
      );

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

    // Wait for sessions and machines to load before marking as ready.
    try {
      await Future.wait([
        sessionsSync.awaitQueue(),
        machinesSync.awaitQueue(),
      ]);
      _isReady = true;
    } catch (error) {
      debugPrint('Failed initial ready sync: $error');
    }
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
      for (final sync in messagesSync.values) {
        sync.invalidate();
      }
    });

    socketIoClient.onStatusChange((status) {
      _connectionStatus = status;
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
      _sessionMessages.remove(sessionId);
      _todoLists.remove(sessionId);
      _sessions.remove(sessionId);
      _sessionDataKeys.remove(sessionId);
      encryption.removeSessionEncryption(sessionId);
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

        _sessions
          ..clear()
          ..addEntries(
            decryptedSessions.map((session) => MapEntry(session.id, session)),
          );
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

        _machines
          ..clear()
          ..addEntries(
            decryptedMachines.map((machine) => MapEntry(machine.id, machine)),
          );
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
    try {
      final response = await ApiClient().get('/v1/artifacts');
      if (!ApiClient().isSuccess(response)) {
        debugPrint('Failed to fetch artifacts: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawArtifacts = (data is Map<String, dynamic>)
          ? data['artifacts']
          : data;
      if (rawArtifacts is! List) {
        _artifacts.clear();
        return;
      }

      final decryptedArtifacts = <DecryptedArtifact>[];
      for (final raw in rawArtifacts) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        try {
          final artifact = Artifact.fromJson(raw);
          final decryptedKey = await encryption.decryptEncryptionKey(
            artifact.dataEncryptionKey,
          );
          if (decryptedKey != null) {
            _artifactDataKeys[artifact.id] = decryptedKey;
            final artifactEncryption = ArtifactEncryption(decryptedKey);
            final header = await artifactEncryption.decryptHeader(artifact.header);
            final body = artifact.body != null
                ? await artifactEncryption.decryptBody(artifact.body!)
                : null;

            decryptedArtifacts.add(
              DecryptedArtifact(
                id: artifact.id,
                title: header?['title'] as String?,
                sessions: (header?['sessions'] as List<dynamic>?)
                    ?.whereType<String>()
                    .toList(),
                draft: header?['draft'] as bool?,
                body: body?['body'] as String?,
                headerVersion: artifact.headerVersion,
                bodyVersion: artifact.bodyVersion,
                seq: artifact.seq,
                createdAt: artifact.createdAt,
                updatedAt: artifact.updatedAt,
                isDecrypted: header != null,
              ),
            );
          } else {
            decryptedArtifacts.add(
              DecryptedArtifact(
                id: artifact.id,
                title: null,
                body: null,
                headerVersion: artifact.headerVersion,
                bodyVersion: artifact.bodyVersion,
                seq: artifact.seq,
                createdAt: artifact.createdAt,
                updatedAt: artifact.updatedAt,
                isDecrypted: false,
              ),
            );
          }
        } catch (error) {
          debugPrint('Failed to decrypt artifact: $error');
        }
      }

      _artifacts
        ..clear()
        ..addAll(decryptedArtifacts);
      debugPrint('Fetched artifacts: ${_artifacts.length}');
    } catch (error) {
      debugPrint('Failed to fetch artifacts: $error');
    }
  }

  /// Fetch friends list from server
  Future<void> fetchFriends() async {
    debugPrint('Fetching friends...');
    try {
      final response = await ApiClient().get('/v1/friends');
      if (!ApiClient().isSuccess(response)) {
        debugPrint('Failed to fetch friends: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawFriends = (data is Map<String, dynamic>)
          ? data['friends']
          : data;
      if (rawFriends is! List) {
        _friends.clear();
        _friendRequests.clear();
        return;
      }

      final parsedFriends = <UserProfile>[];
      for (final raw in rawFriends) {
        if (raw is Map<String, dynamic>) {
          parsedFriends.add(_mapFriendProfile(raw));
        }
      }

      _friends
        ..clear()
        ..addAll(parsedFriends);
      _friendRequests
        ..clear()
        ..addAll(_deriveFriendRequests(parsedFriends));

      debugPrint(
        'Fetched friends: ${_friends.length}, '
        'pending requests: ${_friendRequests.length}',
      );
    } catch (error) {
      debugPrint('Failed to fetch friends: $error');
    }
  }

  /// Fetch friend requests from server (backward compatibility)
  Future<void> fetchFriendRequests() async {
    await fetchFriends();
  }

  /// Fetch feed items from server
  Future<void> fetchFeed() async {
    debugPrint('Fetching feed...');
    try {
      final response = await ApiClient().get(
        '/v1/feed',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      if (!ApiClient().isSuccess(response)) {
        debugPrint('Failed to fetch feed: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawItems = (data is Map<String, dynamic>)
          ? data['items']
          : data;
      if (rawItems is! List) {
        _feedItems.clear();
        return;
      }

      final parsed = <FeedItem>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          parsed.add(_mapFeedItem(raw));
        }
      }

      _feedItems
        ..clear()
        ..addAll(parsed);
      debugPrint('Fetched feed items: ${_feedItems.length}');
    } catch (error) {
      debugPrint('Failed to fetch feed: $error');
    }
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

  @visibleForTesting
  UserProfile mapFriendProfile(Map<String, dynamic> raw) {
    return _mapFriendProfile(raw);
  }

  UserProfile _mapFriendProfile(Map<String, dynamic> raw) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = (raw['id'] as String?) ??
        (raw['uid'] as String?) ??
        'unknown';
    final firstName = raw['firstName'] as String?;
    final lastName = raw['lastName'] as String?;
    final username = raw['username'] as String?;
    final name = [firstName, lastName]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
    final avatar = raw['avatar'];
    String? avatarUrl;
    if (avatar is Map<String, dynamic>) {
      avatarUrl = avatar['url'] as String?;
    } else {
      avatarUrl = raw['avatarUrl'] as String?;
    }

    return UserProfile(
      id: id,
      name: name.isNotEmpty ? name : username,
      email: raw['email'] as String?,
      avatarUrl: avatarUrl,
      status: _mapRelationshipStatus(raw['status'] as String?),
      lastSeenAt: _asInt(raw['lastSeenAt']),
      createdAt: _asInt(raw['createdAt']) ?? now,
    );
  }

  RelationshipStatus _mapRelationshipStatus(String? status) {
    switch (status) {
      case 'friend':
      case 'friends':
        return RelationshipStatus.friends;
      case 'requested':
        return RelationshipStatus.pendingOutgoing;
      case 'pending':
        return RelationshipStatus.pendingIncoming;
      case 'blocked':
        return RelationshipStatus.blocked;
      case 'blockedByThem':
        return RelationshipStatus.blockedByThem;
      default:
        return RelationshipStatus.none;
    }
  }

  List<FriendRequest> _deriveFriendRequests(List<UserProfile> profiles) {
    return profiles
        .where((profile) => profile.status == RelationshipStatus.pendingIncoming)
        .map((profile) => FriendRequest(
              id: 'friend-request-${profile.id}',
              fromUserId: profile.id,
              fromUserName: profile.name ?? profile.id,
              fromUserAvatarUrl: profile.avatarUrl,
              toUserId: serverID,
              createdAt: profile.createdAt,
              status: 'pending',
            ))
        .toList();
  }

  @visibleForTesting
  FeedItem mapFeedItem(Map<String, dynamic> raw) {
    return _mapFeedItem(raw);
  }

  FeedItem _mapFeedItem(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? '';
    final createdAt =
        _asInt(raw['createdAt']) ?? DateTime.now().millisecondsSinceEpoch;
    final bodyRaw = raw['body'];
    final bodyMap = bodyRaw is Map<String, dynamic>
        ? bodyRaw
        : <String, dynamic>{};
    final kind = bodyMap['kind'] as String?;

    FeedType type;
    FeedBody body;
    String userId = raw['userId'] as String? ?? 'system';

    switch (kind) {
      case 'friend_request':
        type = FeedType.friendRequest;
        userId = (bodyMap['uid'] as String?) ?? userId;
        body = FeedBody(
          title: 'Friend request',
          message: 'New friend request',
          extra: bodyMap,
        );
        break;
      case 'friend_accepted':
        type = FeedType.friendAccepted;
        userId = (bodyMap['uid'] as String?) ?? userId;
        body = FeedBody(
          title: 'Friend accepted',
          message: 'Your request was accepted',
          extra: bodyMap,
        );
        break;
      case 'text':
        type = FeedType.system;
        body = FeedBody(
          title: 'Update',
          message: bodyMap['text'] as String?,
          extra: bodyMap,
        );
        break;
      default:
        type = FeedType.system;
        body = FeedBody(
          title: 'Update',
          message: raw['message'] as String?,
          extra: bodyMap.isEmpty ? raw : bodyMap,
        );
        break;
    }

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      type: type,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
    );
  }

  /// Sync settings with server
  Future<void> syncSettings() async {
    debugPrint('Syncing settings...');

    try {
      final apiClient = ApiClient();

      // Apply pending settings
      if (pendingSettings.isNotEmpty) {
        final mergedSettings = Settings.fromJson({
          ..._settingsSnapshot.toJson(),
          ...pendingSettings,
        });
        final encryptedPending = await encryption.encryptRaw(
          mergedSettings.toJson(),
        ) as String;

        final updateResponse = await apiClient.post(
          '/v1/account/settings',
          data: {
            'settings': encryptedPending,
            'expectedVersion': _settingsVersion,
          },
        );

        final updateData = updateResponse.data as Map<String, dynamic>?;
        final updateSuccess = updateData?['success'] == true;
        if (apiClient.isSuccess(updateResponse) && updateSuccess) {
          _settingsSnapshot = mergedSettings;
          pendingSettings.clear();
        } else if (updateData?['error'] == 'version-mismatch') {
          final currentSettingsEncrypted =
              updateData?['currentSettings'] as String?;
          final currentVersion = _asInt(updateData?['currentVersion']) ?? 0;
          final serverSettingsMap = currentSettingsEncrypted != null
              ? await encryption.decryptRaw(currentSettingsEncrypted)
                  as Map<String, dynamic>?
              : null;
          final serverSettings = Settings.fromJson(serverSettingsMap ?? {});
          _settingsSnapshot = Settings.fromJson({
            ...serverSettings.toJson(),
            ...pendingSettings,
          });
          _settingsVersion = currentVersion;
        }
      }

      // Fetch latest settings
      final response = await apiClient.get('/v1/account/settings');

      if (apiClient.isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        final encryptedSettings = data['settings'] as String?;

        if (encryptedSettings != null) {
          final decrypted = await encryption.decryptRaw(encryptedSettings)
              as Map<String, dynamic>?;
          if (decrypted != null) {
            _settingsSnapshot = Settings.fromJson(decrypted);
            _settingsVersion = _asInt(data['settingsVersion']) ?? _settingsVersion;
          }
        } else {
          _settingsSnapshot = Settings();
          _settingsVersion = _asInt(data['settingsVersion']) ?? _settingsVersion;
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
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/account/profile');
      if (!apiClient.isSuccess(response)) {
        return;
      }

      final data = response.data as Map<String, dynamic>?;
      _purchases = Purchases.parse(data?['purchases']);
    } catch (error) {
      debugPrint('Failed to sync purchases: $error');
    }
  }

  /// Fetch profile from server
  Future<void> fetchProfile() async {
    debugPrint('Fetching profile...');

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get('/v1/account/profile');

      if (apiClient.isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        _profile = Profile.fromJson(data);
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
    if (kIsWeb) {
      _nativeUpdateUrl = null;
      return;
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) {
      _nativeUpdateUrl = null;
      return;
    }

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/v1/version',
        data: <String, dynamic>{
          'platform': platform,
          'version':
              const String.fromEnvironment('FLUTTER_BUILD_NAME',
                  defaultValue: '1.0.0'),
          'app_id':
              const String.fromEnvironment('FLUTTER_APPLICATION_ID',
                  defaultValue: 'happy.flutter'),
        },
      );
      if (!apiClient.isSuccess(response)) {
        _nativeUpdateUrl = null;
        return;
      }

      final data = response.data as Map<String, dynamic>?;
      final updateUrl = data?['updateUrl'] as String? ??
          data?['update_url'] as String?;
      _nativeUpdateUrl =
          updateUrl != null && updateUrl.isNotEmpty ? updateUrl : null;
    } catch (error) {
      debugPrint('Failed to fetch native update: $error');
      _nativeUpdateUrl = null;
    }
  }

  /// Register or refresh device push token
  Future<void> syncPushToken() async {
    debugPrint('Syncing push token...');
    if (kIsWeb) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      if (_registeredPushToken == token) {
        return;
      }

      await PushApi().registerToken(token);
      _registeredPushToken = token;
    } catch (error) {
      debugPrint('Failed to sync push token: $error');
    }
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
    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      debugPrint('Session encryption not initialized for $sessionId');
      return;
    }

    final session = _sessions[sessionId];
    if (session == null) {
      debugPrint('Session $sessionId not loaded');
      return;
    }

    final permissionMode = session.permissionMode ?? 'default';
    final flavor = session.metadata?.flavor;
    final isGemini = flavor == 'gemini';
    final modelMode = session.modelMode ??
        (isGemini ? 'gemini-2.5-pro' : 'default');
    final localId = encryption.generateId();
    final sentFrom = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'mac',
      _ => 'web',
    };
    final model = isGemini && modelMode != 'default' ? modelMode : null;

    final rawRecord = <String, dynamic>{
      'role': 'user',
      'content': <String, dynamic>{
        'type': 'text',
        'text': text,
      },
      'meta': <String, dynamic>{
        'sentFrom': sentFrom,
        'permissionMode': permissionMode,
        'model': model,
        'fallbackModel': null,
        'appendSystemPrompt': _appendSystemPrompt,
        if (displayText != null) 'displayText': displayText,
      },
    };

    final encryptedRawRecord = await sessionEncryption.encryptRawRecord(
      rawRecord,
    );

    _upsertSessionMessages(
      sessionId,
      [
        {
          'id': localId,
          'localId': localId,
          'seq': 0,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'role': 'user',
          'kind': 'text',
          'content': text,
          'raw': rawRecord,
        },
      ],
    );

    final ready = await waitForAgentReady(sessionId);
    if (!ready) {
      debugPrint(
        'Session $sessionId not marked ready after timeout, sending anyway',
      );
    }

    socketIoClient.send(
      'message',
      {
        'sid': sessionId,
        'message': encryptedRawRecord,
        'localId': localId,
        'sentFrom': sentFrom,
        'permissionMode': permissionMode,
      },
    );
  }

  /// Apply settings delta
  Future<void> applySettings(Map<String, dynamic> delta) async {
    _settingsSnapshot = Settings.fromJson({
      ..._settingsSnapshot.toJson(),
      ...delta,
    });
    pendingSettings = {
      ...pendingSettings,
      ...delta,
    };
    settingsSync.invalidate();
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
        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList()
            .reversed
            .toList();

        final receivedMessages = sessionReceivedMessages.putIfAbsent(
          sessionId,
          () => <String>{},
        );
        final toDecrypt = <Map<String, dynamic>>[];
        for (final message in messages) {
          final messageId = message['id'] as String?;
          if (messageId == null || receivedMessages.contains(messageId)) {
            continue;
          }
          toDecrypt.add(message);
        }

        final decryptedMessages = await sessionEncryption.decryptMessages(
          toDecrypt,
        );

        final mappedMessages = <Map<String, dynamic>>[];
        for (final decrypted in decryptedMessages) {
          if (decrypted == null || decrypted.content == null) {
            continue;
          }
          receivedMessages.add(decrypted.id);
          final mapped = _mapDecryptedSessionMessage(decrypted);
          mappedMessages.add(mapped);
        }

        if (mappedMessages.isNotEmpty) {
          _upsertSessionMessages(sessionId, mappedMessages);
        }
      } else {
        debugPrint('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching messages: $error');
    }
  }

  /// Wait for agent to be ready
  Future<bool> waitForAgentReady(String sessionId, [int timeoutMs = SESSION_READY_TIMEOUT_MS]) async {
    final timeoutAt = DateTime.now().millisecondsSinceEpoch + timeoutMs;
    while (DateTime.now().millisecondsSinceEpoch < timeoutAt) {
      final session = _sessions[sessionId];
      if (session != null && session.agentStateVersion > 0) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Map<String, dynamic> _mapDecryptedSessionMessage(DecryptedMessage message) {
    final createdAt = message.createdAt.millisecondsSinceEpoch;
    final content = message.content;
    if (content is Map<String, dynamic>) {
      final role = content['role'] as String?;
      final nestedContent = content['content'];
      if (nestedContent is Map<String, dynamic>) {
        final type = nestedContent['type'] as String?;
        if (type == 'text') {
          return {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': role,
            'kind': 'text',
            'content': nestedContent['text']?.toString() ?? '',
            'raw': content,
          };
        }
        if (type == 'tool_use') {
          return {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': role,
            'kind': 'tool-call',
            'name': nestedContent['name'],
            'input': nestedContent['input'],
            'toolUseId': nestedContent['id'],
            'content': nestedContent,
            'raw': content,
          };
        }
      }

      return {
        'id': message.id,
        'localId': message.localId,
        'seq': message.seq,
        'createdAt': createdAt,
        'role': role,
        'kind': 'unknown',
        'content': content.toString(),
        'raw': content,
      };
    }

    return {
      'id': message.id,
      'localId': message.localId,
      'seq': message.seq,
      'createdAt': createdAt,
      'kind': 'text',
      'content': content?.toString() ?? '',
      'raw': content,
    };
  }

  void _upsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    final merged = <String, Map<String, dynamic>>{
      for (final message in existing) message['id'] as String: message,
    };
    for (final message in messages) {
      final messageId = message['id'] as String;
      merged[messageId] = message;
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        final aCreated = _asInt(a['createdAt']) ?? 0;
        final bCreated = _asInt(b['createdAt']) ?? 0;
        if (aCreated != bCreated) {
          return aCreated.compareTo(bCreated);
        }
        return (a['seq'] as int? ?? 0).compareTo(b['seq'] as int? ?? 0);
      });
    _sessionMessages[sessionId] = sorted;
  }

  /// Shutdown sync engine and clear volatile state.
  Future<void> shutdown() async {
    socketIoClient.offMessage('update');
    socketIoClient.offMessage('ephemeral');
    socketIoClient.disconnect();

    for (final sync in messagesSync.values) {
      sync.dispose();
    }
    messagesSync.clear();
    sessionReceivedMessages.clear();

    sessionsSync.dispose();
    settingsSync.dispose();
    profileSync.dispose();
    purchasesSync.dispose();
    machinesSync.dispose();
    pushTokenSync.dispose();
    nativeUpdateSync.dispose();
    artifactsSync.dispose();
    friendsSync.dispose();
    friendRequestsSync.dispose();
    feedSync.dispose();
    todosSync.dispose();

    _sessionDataKeys.clear();
    _machineDataKeys.clear();
    _artifactDataKeys.clear();
    _todoLists.clear();
    _friends.clear();
    _friendRequests.clear();
    _feedItems.clear();
    _artifacts.clear();
    _sessionMessages.clear();
    _sessions.clear();
    _machines.clear();
    _profile = null;
    _settingsSnapshot = Settings();
    _settingsVersion = 0;
    _purchases = Purchases.defaults;
    pendingSettings.clear();
    _registeredPushToken = null;
    _nativeUpdateUrl = null;
    _isReady = false;
    _connectionStatus = ConnectionStatus.disconnected;
    isInitialized = false;
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

/// Shutdown sync engine and clear in-memory state.
Future<void> syncShutdown() async {
  if (!sync.isInitialized) {
    return;
  }
  await sync.shutdown();
}
