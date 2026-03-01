import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../api/kv_api.dart';
import '../api/push_api.dart';
import '../api/socket_io_client.dart';
import '../encryption/aes_gcm.dart';
import '../encryption/artifact_encryption.dart';
import '../encryption/base64.dart';
import '../encryption/crypto_secret_box.dart';
import '../encryption/encryption_cache.dart';
import '../encryption/encryption_manager.dart';
import '../models/api_update.dart';
import '../models/artifact.dart';
import '../models/auth.dart';
import '../models/built_in_profiles.dart';
import '../models/feed.dart';
import '../models/friend.dart';
import '../models/machine.dart';
import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/todo.dart';
import '../rpc/rpc_types.dart';
import '../services/mmkv_storage.dart';
import '../services/server_config.dart';
import '../utils/invalidate_sync.dart';
import '../utils/parse_token.dart';

// ── Isolate helpers: machine payload decryption ──────────────────────────

class _MachineIsolateItem {
  const _MachineIsolateItem({
    required this.id,
    required this.secretKey,
    required this.isAes,
    required this.metadataVersion,
    required this.daemonStateVersion,
    this.encryptedMetadata,
    this.encryptedDaemonState,
  });

  final String id;
  final Uint8List secretKey;
  final bool isAes;
  final Uint8List? encryptedMetadata;
  final int metadataVersion;
  final Uint8List? encryptedDaemonState;
  final int daemonStateVersion;
}

class _MachineIsolateResult {
  const _MachineIsolateResult({
    required this.id,
    this.metadata,
    this.daemonState,
  });

  final String id;
  final Map<String, dynamic>? metadata;
  final dynamic daemonState;
}

// ── Isolate helpers: artifact payload decryption ──────────────────────────

class _ArtifactIsolateItem {
  const _ArtifactIsolateItem({
    required this.id,
    required this.secretKey,
    required this.encryptedHeader,
    this.encryptedBody,
  });

  final String id;
  final Uint8List secretKey;
  final Uint8List encryptedHeader;
  final Uint8List? encryptedBody;
}

class _ArtifactIsolateResult {
  const _ArtifactIsolateResult({
    required this.id,
    this.header,
    this.body,
  });

  final String id;
  final Map<String, dynamic>? header;
  final Map<String, dynamic>? body;
}

/// Decrypt machine metadata and daemonState in a background isolate.
/// Handles both AES-256-GCM (isAes=true) and NaCl SecretBox
/// (isAes=false, legacy machines).
Future<List<_MachineIsolateResult>> _decryptMachinesInIsolate(
  List<_MachineIsolateItem> items,
) async {
  final results = <_MachineIsolateResult>[];
  for (final item in items) {
    Map<String, dynamic>? metadata;
    dynamic daemonState;

    final encMeta = item.encryptedMetadata;
    if (encMeta != null) {
      try {
        if (item.isAes) {
          if (encMeta.isNotEmpty && encMeta[0] == 0) {
            final d = await AesGcmEncryption.decrypt(
              encMeta.sublist(1),
              item.secretKey,
            );
            if (d is Map<String, dynamic>) metadata = d;
          }
        } else {
          final d = await CryptoSecretBox.decrypt(
            encMeta,
            item.secretKey,
          );
          if (d is Map<String, dynamic>) metadata = d;
        }
      } catch (_) {}
    }

    final encDs = item.encryptedDaemonState;
    if (encDs != null) {
      try {
        if (item.isAes) {
          if (encDs.isNotEmpty && encDs[0] == 0) {
            daemonState = await AesGcmEncryption.decrypt(
              encDs.sublist(1),
              item.secretKey,
            );
          }
        } else {
          daemonState = await CryptoSecretBox.decrypt(
            encDs,
            item.secretKey,
          );
        }
      } catch (_) {}
    }

    results.add(_MachineIsolateResult(
      id: item.id,
      metadata: metadata,
      daemonState: daemonState,
    ));
  }
  return results;
}

/// Decrypt artifact headers and bodies in a background isolate.
/// Artifacts always use AES-256-GCM.
Future<List<_ArtifactIsolateResult>> _decryptArtifactsInIsolate(
  List<_ArtifactIsolateItem> items,
) async {
  final results = <_ArtifactIsolateResult>[];
  for (final item in items) {
    Map<String, dynamic>? header;
    Map<String, dynamic>? body;

    final hRaw = item.encryptedHeader;
    if (hRaw.isNotEmpty && hRaw[0] == 0) {
      try {
        final d = await AesGcmEncryption.decrypt(
          hRaw.sublist(1),
          item.secretKey,
        );
        if (d is Map<String, dynamic>) header = d;
      } catch (_) {}
    }

    final bRaw = item.encryptedBody;
    if (bRaw != null && bRaw.isNotEmpty && bRaw[0] == 0) {
      try {
        final d = await AesGcmEncryption.decrypt(
          bRaw.sublist(1),
          item.secretKey,
        );
        if (d is Map<String, dynamic>) {
          body = {'body': d['body'] as String?};
        }
      } catch (_) {}
    }

    results.add(_ArtifactIsolateResult(
      id: item.id,
      header: header,
      body: body,
    ));
  }
  return results;
}

int? _asSessionInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

// Global singleton instance
class Sync {
  factory Sync() => _instance;
  Sync._();
  static final Sync _instance = Sync._();

  // Constants
  static const int sessionReadyTimeoutMs = 10000;

  /// Number of recent messages to load on first open of a session.
  static const int initialLoad = 200;
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
  final Map<String, int> _sessionLastSeq = {};

  /// Tracks the lowest seq loaded for each session. A value of 0 means
  /// we have loaded from the very beginning (no older messages exist).
  final Map<String, int> _sessionFirstLoadedSeq = {};

  /// The session the user is currently viewing.  Updated by
  /// [onSessionVisible].  Used by [fetchMessages] to bail out
  /// early when the user navigates away mid-fetch.
  String? _visibleSessionId;

  /// Sessions currently being paginated backwards (older-message loads).
  final Set<String> _loadingOlderMessages = {};
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
  late InvalidateSync sessionGitStatusSync;

  // State tracking
  bool revenueCatInitialized = false;
  bool isInitialized = false;
  bool _isReady = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _registeredPushToken;
  String? _nativeUpdateUrl;

  // Pending settings
  Map<String, dynamic> pendingSettings = {};
  final Map<String?, TodoList> _todoLists = <String?, TodoList>{};
  final List<UserProfile> _friends = <UserProfile>[];
  final List<FriendRequest> _friendRequests = <FriendRequest>[];
  final List<FeedItem> _feedItems = <FeedItem>[];
  final List<DecryptedArtifact> _artifacts = <DecryptedArtifact>[];
  final Map<String, List<Map<String, dynamic>>> _sessionMessages = {};
  Map<String, List<Map<String, dynamic>>>?
      _sessionMessagesCache;
  final Map<String, Map<String, dynamic>> _sessionUsage = {};
  Settings _settingsSnapshot = Settings();
  int _settingsVersion = 0;
  Purchases _purchases = Purchases.defaults;
  final Map<String, Session> _sessions = <String, Session>{};
  int? _lastSessionsFetchedAt;
  bool _forceFullFetchNext = false;
  final Map<String, Machine> _machines = <String, Machine>{};
  // Timers that drop presence back to 'offline' if no activity arrives.
  final Map<String, Timer> _presenceTimers = {};
  Profile? _profile;
  final Map<String, GitStatus> _sessionGitStatus = <String, GitStatus>{};

  // Change notification streams
  final _dataChangeController = StreamController<void>.broadcast();
  final _sessionMessageChangeController =
      StreamController<String>.broadcast();
  Timer? _dataChangeDebounceTimer;
  Timer? _saveSeqDebounceTimer;

  Map<String?, TodoList> get todoLists => Map.unmodifiable(_todoLists);
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get friendRequests => List.unmodifiable(_friendRequests);
  List<FeedItem> get feedItems => List.unmodifiable(_feedItems);
  List<DecryptedArtifact> get artifacts => List.unmodifiable(_artifacts);
  /// Get usage data for a session (contextSize, inputTokens, outputTokens).
  Map<String, Map<String, dynamic>> get sessionUsage =>
      Map.unmodifiable(_sessionUsage);
  Settings get settingsSnapshot => _settingsSnapshot;
  int get settingsVersion => _settingsVersion;
  Purchases get purchases => _purchases;
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);

  @visibleForTesting
  Map<String, Session> get testSessions => _sessions;

  @visibleForTesting
  int? get testLastSessionsFetchedAt => _lastSessionsFetchedAt;

  @visibleForTesting
  set testLastSessionsFetchedAt(int? value) => _lastSessionsFetchedAt = value;

  @visibleForTesting
  bool get testForceFullFetchNext => _forceFullFetchNext;

  @visibleForTesting
  set testForceFullFetchNext(bool value) => _forceFullFetchNext = value;

  Map<String, Machine> get machines => Map.unmodifiable(_machines);
  Profile? get profile => _profile;
  bool get isReady => _isReady;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get nativeUpdateUrl => _nativeUpdateUrl;
  bool get hasNativeUpdate => _nativeUpdateUrl != null;
  Map<String, GitStatus> get sessionGitStatus =>
      Map.unmodifiable(_sessionGitStatus);
  Map<String, List<Map<String, dynamic>>>
      get sessionMessages {
    _sessionMessagesCache ??= Map.unmodifiable(
      _sessionMessages.map(
        (key, value) => MapEntry(
          key,
          List<Map<String, dynamic>>.unmodifiable(value),
        ),
      ),
    );
    return _sessionMessagesCache!;
  }

  /// Returns the messages for a single session without copying all sessions.
  List<Map<String, dynamic>> messagesForSession(String sessionId) =>
      List.unmodifiable(_sessionMessages[sessionId] ?? const []);

  /// Returns the timestamp of the last message in a session, or null if
  /// there are no messages.
  int? getLastMessageTimestamp(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return null;
    // Messages are stored in ascending seq order, so the last one has the
    // highest seq (most recent).
    final lastMessage = messages.last;
    return lastMessage['createdAt'] as int?;
  }

  /// Returns true when there are older messages available for [sessionId]
  /// that have not yet been loaded.
  bool hasOlderMessages(String sessionId) {
    final firstLoaded = _sessionFirstLoadedSeq[sessionId];
    return firstLoaded != null && firstLoaded > 1;
  }

  /// Returns true while an older-message page fetch is in progress for
  /// [sessionId].
  bool isLoadingOlderMessages(String sessionId) =>
      _loadingOlderMessages.contains(sessionId);

  /// Stream that emits when session/machine/general data changes.
  Stream<void> get onDataChanged => _dataChangeController.stream;

  /// Stream that emits the sessionId when messages for that session change.
  Stream<String> get onSessionMessagesChanged =>
      _sessionMessageChangeController.stream;

  /// Initialize sync with credentials and encryption
  Future<void> create(
    AuthCredentials credentials,
    Encryption encryption,
  ) async {
    if (isInitialized) {
      if (kDebugMode) debugPrint('Sync already initialized');
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
  Future<void> restore(
    AuthCredentials credentials,
    Encryption encryption,
  ) async {
    if (isInitialized) {
      if (kDebugMode) debugPrint('Sync already initialized');
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
    // Restore persisted message cursors
    _sessionLastSeq
      ..clear()
      ..addAll(MMKVStorage().getSessionLastSeq());
    _sessionFirstLoadedSeq
      ..clear()
      ..addAll(MMKVStorage().getSessionFirstLoadedSeq());

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
    sessionGitStatusSync = InvalidateSync(_fetchSessionGitStatus);

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
      if (kDebugMode) debugPrint('Failed initial ready sync: $error');
    }
  }

  /// Invalidate all sync managers
  void _invalidateAllSyncs() {
    // Reset the delta-fetch timestamp so reconnect / foreground-resume always
    // triggers a full session list fetch.  Without this, a clock adjustment
    // (NTP, DST, timezone change) while offline can push _lastSessionsFetchedAt
    // ahead of any sessions created during the offline period, causing them to
    // be permanently missed by every subsequent delta fetch.
    _lastSessionsFetchedAt = null;
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
    sessionGitStatusSync.invalidate();
  }

  /// Debounced data change notification.
  /// Batches rapid successive emissions within 16ms window.
  void _notifyDataChanged() {
    _dataChangeDebounceTimer?.cancel();
    _dataChangeDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_dataChangeController.isClosed) {
        _dataChangeController.add(null);
      }
    });
  }

  /// Debounced MMKV persist for session seq cursors.
  ///
  /// [saveSessionLastSeq] does a synchronous jsonEncode + MMKV disk write on
  /// the main thread. Called on every pagination page during [fetchMessages],
  /// it was the single biggest cause of jank when opening large sessions.
  /// We debounce to a 500ms window so rapid page fetches batch into one write.
  void _scheduleSaveSeq() {
    _saveSeqDebounceTimer?.cancel();
    _saveSeqDebounceTimer =
        Timer(const Duration(milliseconds: 500), () {
      MMKVStorage().saveSessionLastSeq(
        Map.unmodifiable(_sessionLastSeq),
      );
    });
  }

  /// Subscribe to socket updates
  void subscribeToUpdates() {
    socketIoClient
      ..onMessage('update', handleUpdate)
      ..onMessage('ephemeral', handleEphemeralUpdate)
      ..onReconnected(() {
        if (kDebugMode) debugPrint('Socket reconnected');
        _invalidateAllSyncs();
        // Only re-fetch messages for the currently visible session.
        // All other sessions will be lazily refreshed when the user
        // navigates to them via onSessionVisible(). Invalidating every
        // messagesSync entry caused a thundering herd of concurrent
        // fetchMessages calls on reconnect, blocking the main thread.
        if (_visibleSessionId != null) {
          messagesSync[_visibleSessionId]?.invalidate();
        }
      })
      ..onStatusChange((status) {
        _connectionStatus = status;
      });
  }

  /// Handle incoming updates
  void handleUpdate(dynamic data) {
    if (data is! Map<String, dynamic>) {
      if (kDebugMode) {
        debugPrint('handleUpdate: unexpected data type: ${data.runtimeType}');
      }
      return;
    }
    try {
      final update = ApiUpdate.fromJson(data);

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
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to handle update: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Handle new message update
  void _handleNewMessage(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
    if (kDebugMode) {
      debugPrint(
        'New message received'
        '${sessionId != null ? ': $sessionId' : ''}',
      );
    }
  }

  /// Handle new session update
  void _handleNewSession(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('New session received');
    final sessionId = data['id'] as String? ?? data['sid'] as String?;
    sessionsSync.invalidateAndAwait().then((_) {
      // Apply the same guard used in createSession: if the delta fetch missed
      // the new session (clock skew between client and server), force a full
      // (non-delta) fetch so the session's encryption is initialized.
      if (sessionId != null &&
          encryption.getSessionEncryption(sessionId) == null) {
        _forceFullFetchNext = true;
        sessionsSync.invalidateAndAwait();
      }
    });
  }

  /// Handle session deletion
  void _handleDeleteSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null) {
      messagesSync.remove(sessionId)?.dispose();
      _loadingOlderMessages.remove(sessionId);
      _sessionMessages.remove(sessionId);
      _sessionMessagesCache = null;
      _todoLists.remove(sessionId);
      _sessions.remove(sessionId);
      _presenceTimers.remove(sessionId)?.cancel();
      _sessionDataKeys.remove(sessionId);
      if (isInitialized) {
        _sessionLastSeq.remove(sessionId);
        MMKVStorage().saveSessionLastSeq(
          Map.unmodifiable(_sessionLastSeq),
        );
        _sessionFirstLoadedSeq.remove(sessionId);
        MMKVStorage().saveSessionFirstLoadedSeq(
          Map.unmodifiable(_sessionFirstLoadedSeq),
        );
        encryption.removeSessionEncryption(sessionId);
      }
    }
    sessionsSync.invalidate();
    if (kDebugMode) {
      debugPrint(
        'Session deletion received'
        '${sessionId != null ? ': $sessionId' : ''}',
      );
    }
  }

  /// Handle session update
  void _handleUpdateSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String?;
    sessionsSync.invalidate();
    if (sessionId != null && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
    if (kDebugMode) {
      debugPrint(
        'Session update received'
        '${sessionId != null ? ': $sessionId' : ''}',
      );
    }
  }

  /// Handle account update
  void _handleUpdateAccount(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('Account update received');
    profileSync.invalidate();
    settingsSync.invalidate();
  }

  /// Handle machine update
  void _handleUpdateMachine(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('Machine update received');
    machinesSync.invalidate();
  }

  /// Handle relationship update
  void _handleRelationshipUpdated(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('Relationship update received');
    friendsSync.invalidate();
    friendRequestsSync.invalidate();
    feedSync.invalidate();
  }

  /// Handle new artifact update
  void _handleNewArtifact(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('New artifact received');
    artifactsSync.invalidate();
  }

  /// Handle artifact update
  void _handleUpdateArtifact(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('Artifact update received');
    artifactsSync.invalidate();
  }

  /// Handle artifact deletion
  void _handleDeleteArtifact(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('Artifact deletion received');
    artifactsSync.invalidate();
  }

  /// Handle new feed post
  void _handleNewFeedPost(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('New feed post received');
    feedSync.invalidate();
  }

  /// Check if data contains a key matching the search string
  /// without full JSON serialization.
  bool _containsKeyRecursive(
    dynamic data,
    String key,
  ) {
    if (data is Map) {
      for (final k in data.keys) {
        if (k is String &&
            k.toLowerCase().contains(key)) {
          return true;
        }
        if (_containsKeyRecursive(data[k], key)) {
          return true;
        }
      }
    } else if (data is List) {
      for (final item in data) {
        if (_containsKeyRecursive(item, key)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Handle KV batch update (for todos)
  void _handleKvBatchUpdate(Map<String, dynamic> data) {
    final changes = data['changes'];
    if (changes is List &&
        changes.any((change) =>
            change is Map<String, dynamic> &&
            ((change['key'] as String?)?.startsWith('todo.') ?? false))) {
      todosSync.invalidate();
      if (kDebugMode) {
        debugPrint('KV batch update received (todos)');
      }
      return;
    }

    if (_containsKeyRecursive(data, 'todo')) {
      todosSync.invalidate();
      if (kDebugMode) {
        debugPrint('KV batch update received (todos-fallback)');
      }
      return;
    }

    if (kDebugMode) debugPrint('KV batch update received (non-todo)');
  }

  /// Handle ephemeral updates
  void handleEphemeralUpdate(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return;
    }

    final type = data['type'] as String?;
    // Activity events use 'id'; fall back to 'sid' for other shapes.
    final sessionId =
        data['id'] as String? ?? data['sid'] as String?;
    if (sessionId == null) {
      return;
    }

    if (type == 'activity') {
      final session = _sessions[sessionId];
      if (session != null) {
        final thinking = data['thinking'] as bool? ?? false;
        final activeAt = data['activeAt'] as int?;
        // The server can push active:false to explicitly mark a session
        // offline (matches ApiEphemeralActivityUpdateSchema in the
        // reference implementation).
        final isActive = data['active'] as bool? ?? true;

        if (isActive) {
          _sessions[sessionId] = session.copyWith(
            thinking: thinking,
            thinkingAt: thinking
                ? (activeAt ?? DateTime.now().millisecondsSinceEpoch)
                : null,
            presence: 'online',
          );
          _notifyDataChanged();
          // Reset staleness timer — if no further activity arrives within
          // 60 s, drop presence back to inactive so the session stops
          // appearing in the Active section.
          _presenceTimers[sessionId]?.cancel();
          _presenceTimers[sessionId] = Timer(
            const Duration(seconds: 60),
            () {
              _presenceTimers.remove(sessionId);
              final current = _sessions[sessionId];
              if (current != null && current.presence == 'online') {
                _sessions[sessionId] = current.copyWith(
                  presence: 'offline',
                  thinking: false,
                );
                _notifyDataChanged();
              }
            },
          );
        } else {
          // Session explicitly went offline — cancel any timer and
          // immediately mark it inactive.
          _presenceTimers[sessionId]?.cancel();
          _presenceTimers.remove(sessionId);
          _sessions[sessionId] = session.copyWith(
            presence: 'offline',
            thinking: false,
            thinkingAt: null,
          );
          _notifyDataChanged();
        }
      }
      return;
    }

    // Only invalidate if this session is currently open — ephemeral updates
    // for non-visible sessions are not urgent and can wait until the user
    // navigates to them. Invalidating all sessions caused a thundering herd
    // of fetchMessages calls (one per active typing/tool event × every session
    // the user had previously opened), blocking the main thread.
    if (sessionId == _visibleSessionId &&
        messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Fetch sessions from server
  Future<void> fetchSessions() async {
    if (kDebugMode) debugPrint('Fetching sessions...');

    final fetchStartMs = DateTime.now().millisecondsSinceEpoch;
    final forceFullFetch = _forceFullFetchNext;
    if (forceFullFetch) _forceFullFetchNext = false;
    final changedSince = forceFullFetch ? null : _lastSessionsFetchedAt;

    try {
      final apiClient = ApiClient();
      final allSessions = <dynamic>[];
      String? cursor;

      while (true) {
        final response = await apiClient.get(
          '/v2/sessions',
          queryParameters: {
            'limit': 50,
            if (cursor != null) 'cursor': cursor,
            if (changedSince != null) 'changedSince': changedSince,
          },
        );

        if (!apiClient.isSuccess(response)) {
          if (kDebugMode) {
            debugPrint(
              'Failed to fetch sessions: ${response.statusCode}',
            );
          }
          break;
        }

        final data = response.data as Map<String, dynamic>;
        final page = data['sessions'] as List? ?? [];
        allSessions.addAll(page);

        final hasNext = data['hasNext'] as bool? ?? false;
        if (!hasNext) break;
        cursor = data['nextCursor'] as String?;
        if (cursor == null) break;
      }

      if (allSessions.isEmpty && cursor == null) {
        if (changedSince != null) {
          // Delta fetch with no changes — update timestamp and return.
          _lastSessionsFetchedAt = fetchStartMs;
        }
        // Full fetch: either failure or no sessions — don't update.
        return;
      }

      // Initialize session encryptions — yield between each session
      // so the Android main looper can service the ANR watchdog.
      final sessionKeys = <String, Uint8List?>{};
      for (final session in allSessions) {
        // Yield to event queue before each crypto operation.
        await Future<void>.delayed(Duration.zero);

        final sessionId = session['id'] as String;
        final dataEncryptionKey = session['dataEncryptionKey'] as String?;

        if (dataEncryptionKey != null) {
          try {
            final decryptedKey =
                await encryption.decryptEncryptionKey(dataEncryptionKey);
            if (decryptedKey != null) {
              sessionKeys[sessionId] = decryptedKey;
              _sessionDataKeys[sessionId] = decryptedKey;
            } else {
              // DEK decryption returned null — key mismatch or wrong format.
              // Fall back to legacy so the session is still visible in the UI
              // and "Session encryption not initialized" is avoided.  Messages
              // will not decrypt until the user re-authenticates.
              if (kDebugMode) {
                debugPrint(
                  '[Encryption] DEK decryption failed for session $sessionId '
                  '(returned null) — falling back to legacy encryption. '
                  'Run `happy auth debug` and test the printed vector in '
                  'Flutter to confirm key mismatch.',
                );
              }
              sessionKeys[sessionId] = null;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                '[Encryption] DEK decryption threw for session $sessionId: $e '
                '— falling back to legacy encryption.',
              );
            }
            sessionKeys[sessionId] = null;
          }
        } else {
          sessionKeys[sessionId] = null;
        }
      }

      await encryption.initializeSessions(sessionKeys);

      // Decrypt sessions — yield between each so the looper stays
      // responsive even when processing many sessions.
      final decryptedSessions = <Session>[];
      for (final session in allSessions) {
        // Yield to event queue before each session decrypt.
        await Future<void>.delayed(Duration.zero);

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
              metadata:
                  metadata != null ? Metadata.fromJson(metadata) : null,
              metadataVersion: session['metadataVersion'] as int,
              agentState: agentState.isNotEmpty
                  ? AgentState.fromJson(agentState)
                  : null,
              agentStateVersion: session['agentStateVersion'] as int,
              thinking: false,
              thinkingAt: null,
              // REST fetches cannot tell us whether the CLI process is
              // actually running — the server's `active` flag is
              // persistent (true until archived) and stale.  Default
              // to 'offline'; only real-time WebSocket activity events
              // should promote a session to 'online'.  For delta
              // fetches, preserve the existing presence if known.
              presence: _sessions[sessionId]?.presence ?? 'offline',
              lastSeq: session['lastSeq'] as int?,
            );

            decryptedSessions.add(processedSession);
          } catch (error) {
            if (kDebugMode) {
              debugPrint(
                'Failed to decrypt session $sessionId: $error',
              );
            }
          }
        }
      }

      if (changedSince == null) {
        // Full fetch: cancel all presence timers and replace sessions.
        for (final timer in _presenceTimers.values) {
          timer.cancel();
        }
        _presenceTimers.clear();
        _sessions
          ..clear()
          ..addEntries(
            decryptedSessions.map(
              (session) => MapEntry(session.id, session),
            ),
          );
      } else {
        // Delta fetch: merge updated sessions, cancel their stale timers.
        for (final session in decryptedSessions) {
          _sessions[session.id] = session;
          _presenceTimers.remove(session.id)?.cancel();
        }
      }

      // Start 60 s staleness timers for every session that came back
      // 'online' from the server. If no real-time activity event arrives
      // to confirm the session is still running, the timer will drop it
      // to inactive — preventing stale active flags from persisting
      // indefinitely (matches the reference implementation's behaviour).
      for (final s in decryptedSessions) {
        if (s.presence == 'online') {
          _presenceTimers[s.id] = Timer(
            const Duration(seconds: 60),
            () {
              _presenceTimers.remove(s.id);
              final current = _sessions[s.id];
              if (current != null && current.presence == 'online') {
                _sessions[s.id] = current.copyWith(
                  presence: 'offline',
                  thinking: false,
                );
                _notifyDataChanged();
              }
            },
          );
        }
      }

      // Re-apply permission data only for sessions that changed,
      // not all sessions — avoids O(sessions × messages) on every fetch.
      for (final session in decryptedSessions) {
        if (_sessionMessages.containsKey(session.id)) {
          _applyPermissionRequests(session.id);
        }
      }

      if (kDebugMode) {
        debugPrint(
          'Fetched and decrypted ${decryptedSessions.length} sessions',
        );
      }
      _lastSessionsFetchedAt = fetchStartMs;
      _notifyDataChanged();
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Error fetching sessions: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch machines from server
  Future<void> fetchMachines() async {
    if (kDebugMode) debugPrint('Fetching machines...');

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/machines');

      if (apiClient.isSuccess(response)) {
        // Machines response may be a list directly or wrapped in an object
        final rawData = response.data;
        final List data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map<String, dynamic> &&
            rawData['machines'] is List) {
          data = rawData['machines'] as List;
        } else {
          if (kDebugMode) {
            debugPrint(
              'Unexpected response format for machines: '
              '${rawData?.runtimeType}',
            );
          }
          return;
        }

        // Initialize machine encryptions
        final machineKeys = <String, Uint8List?>{};
        for (final machine in data) {
          await Future<void>.delayed(Duration.zero); // yield to event queue
          final machineId = machine['id'] as String;
          final dataEncryptionKey = machine['dataEncryptionKey'] as String?;

          if (dataEncryptionKey != null) {
            try {
              final decryptedKey =
                  await encryption.decryptEncryptionKey(dataEncryptionKey);
              if (decryptedKey != null) {
                machineKeys[machineId] = decryptedKey;
                _machineDataKeys[machineId] = decryptedKey;
              } else {
                if (kDebugMode) {
                  debugPrint(
                    '[Encryption] DEK decryption failed for machine $machineId '
                    '(returned null) — falling back to legacy encryption. '
                    'Run `happy auth debug` to diagnose key mismatch.',
                  );
                }
                machineKeys[machineId] = null;
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                  '[Encryption] DEK decryption threw for machine $machineId: $e '
                  '— falling back to legacy encryption.',
                );
              }
              machineKeys[machineId] = null;
            }
          } else {
            machineKeys[machineId] = null;
          }
        }

        await encryption.initializeMachines(machineKeys);

        // Build isolate payloads for machine decryption.
        final legacyKey = encryption.legacySecretKey;
        final machineIsolateItems = <_MachineIsolateItem>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          if (!machineKeys.containsKey(machineId)) continue;

          final dataKey = machineKeys[machineId];
          final rawMeta = machine['metadata'];
          final encMeta =
              (rawMeta is String && rawMeta.isNotEmpty)
                  ? Base64Utils.decode(rawMeta, Encoding.base64)
                  : null;
          final rawDs = machine['daemonState'] as String?;
          final encDs =
              (rawDs != null && rawDs.isNotEmpty)
                  ? Base64Utils.decode(rawDs, Encoding.base64)
                  : null;

          machineIsolateItems.add(_MachineIsolateItem(
            id: machineId,
            secretKey: dataKey ?? legacyKey,
            isAes: dataKey != null,
            encryptedMetadata: encMeta,
            metadataVersion:
                _asSessionInt(machine['metadataVersion']) ?? 0,
            encryptedDaemonState: encDs,
            daemonStateVersion:
                _asSessionInt(machine['daemonStateVersion']) ?? 0,
          ));
        }

        // Decrypt all machine payloads off the main thread.
        final machineIsolateResults = kIsWeb
            ? await _decryptMachinesInIsolate(machineIsolateItems)
            : await Isolate.run(
                () => _decryptMachinesInIsolate(machineIsolateItems),
              );
        final machineResultById = {
          for (final r in machineIsolateResults) r.id: r,
        };

        final decryptedMachines = <Machine>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final result = machineResultById[machineId];
          if (result == null) continue;

          decryptedMachines.add(Machine(
            id: machineId,
            seq: _asSessionInt(machine['seq']) ?? 0,
            createdAt: _asSessionInt(machine['createdAt']) ?? 0,
            updatedAt: _asSessionInt(machine['updatedAt']) ?? 0,
            active: machine['active'] as bool? ?? false,
            activeAt: _asSessionInt(machine['activeAt']) ?? 0,
            metadata: result.metadata != null
                ? MachineMetadata.fromJson(result.metadata!)
                : null,
            metadataVersion:
                _asSessionInt(machine['metadataVersion']) ?? 0,
            daemonState: result.daemonState,
            daemonStateVersion:
                _asSessionInt(machine['daemonStateVersion']) ?? 0,
          ));
        }

        _machines
          ..clear()
          ..addEntries(
            decryptedMachines.map((machine) => MapEntry(machine.id, machine)),
          );
        if (kDebugMode) {
          debugPrint(
            'Fetched and decrypted ${decryptedMachines.length} machines',
          );
        }
        _notifyDataChanged();
      } else {
        if (kDebugMode) {
          debugPrint(
            'Failed to fetch machines: ${response.statusCode}',
          );
        }
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Error fetching machines: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch artifacts list from server
  Future<void> fetchArtifactsList() async {
    if (kDebugMode) debugPrint('Fetching artifacts...');
    try {
      final response = await ApiClient().get('/v1/artifacts');
      if (!ApiClient().isSuccess(response)) {
        if (kDebugMode) {
          debugPrint(
            'Failed to fetch artifacts: ${response.statusCode}',
          );
        }
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

      // Phase 1: Decrypt artifact data keys on the main thread.
      // CryptoBox.decrypt is fast (single NaCl call per artifact).
      final keyedArtifacts =
          <({Artifact artifact, Uint8List key})>[];
      final decryptedArtifacts = <DecryptedArtifact>[];
      for (final raw in rawArtifacts) {
        await Future<void>.delayed(Duration.zero); // yield to event queue
        if (raw is! Map<String, dynamic>) continue;
        try {
          final artifact = Artifact.fromJson(raw);
          final decryptedKey = await encryption.decryptEncryptionKey(
            artifact.dataEncryptionKey,
          );
          if (decryptedKey != null) {
            _artifactDataKeys[artifact.id] = decryptedKey;
            keyedArtifacts.add(
              (artifact: artifact, key: decryptedKey),
            );
          } else {
            decryptedArtifacts.add(DecryptedArtifact(
              id: artifact.id,
              headerVersion: artifact.headerVersion,
              bodyVersion: artifact.bodyVersion,
              seq: artifact.seq,
              createdAt: artifact.createdAt,
              updatedAt: artifact.updatedAt,
              isDecrypted: false,
            ));
          }
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Failed to parse artifact key: $error');
          }
        }
      }

      // Phase 2: Decrypt headers + bodies off the main thread.
      // AES-GCM pure-Dart decryption can be slow for many artifacts.
      if (keyedArtifacts.isNotEmpty) {
        final artifactIsolateItems = keyedArtifacts.map((e) {
          final encHeader = Base64Utils.decode(
            e.artifact.header,
            Encoding.base64,
          );
          final encBody = e.artifact.body != null
              ? Base64Utils.decode(e.artifact.body!, Encoding.base64)
              : null;
          return _ArtifactIsolateItem(
            id: e.artifact.id,
            secretKey: e.key,
            encryptedHeader: encHeader,
            encryptedBody: encBody,
          );
        }).toList();

        final artifactIsolateResults = kIsWeb
            ? await _decryptArtifactsInIsolate(artifactIsolateItems)
            : await Isolate.run(
                () => _decryptArtifactsInIsolate(artifactIsolateItems),
              );
        final artifactResultById = {
          for (final r in artifactIsolateResults) r.id: r,
        };

        for (final e in keyedArtifacts) {
          final artifact = e.artifact;
          final result = artifactResultById[artifact.id];
          final header = result?.header;
          final body = result?.body;
          decryptedArtifacts.add(DecryptedArtifact(
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
          ));
        }
      }

      _artifacts
        ..clear()
        ..addAll(decryptedArtifacts);
      if (kDebugMode) {
        debugPrint('Fetched artifacts: ${_artifacts.length}');
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to fetch artifacts: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch a single artifact with full body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async {
    try {
      final response = await ApiClient().get('/v1/artifacts/$id');
      if (!ApiClient().isSuccess(response)) {
        if (kDebugMode) {
          debugPrint('Failed to fetch artifact: ${response.statusCode}');
        }
        return null;
      }
      final raw = response.data;
      if (raw is! Map<String, dynamic>) return null;
      final artifact = Artifact.fromJson(raw);
      final decryptedKey = _artifactDataKeys[artifact.id] ??
          await encryption.decryptEncryptionKey(artifact.dataEncryptionKey);
      if (decryptedKey == null) return null;
      _artifactDataKeys[artifact.id] = decryptedKey;
      final artifactEncryption = ArtifactEncryption(decryptedKey);
      final header = await artifactEncryption.decryptHeader(artifact.header);
      final body = artifact.body != null
          ? await artifactEncryption.decryptBody(artifact.body!)
          : null;
      return DecryptedArtifact(
        id: artifact.id,
        title: header?['title'] as String?,
        body: body?['body'] as String?,
        headerVersion: artifact.headerVersion,
        bodyVersion: artifact.bodyVersion,
        seq: artifact.seq,
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
        isDecrypted: header != null,
      );
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to fetch artifact: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
      return null;
    }
  }

  /// Create a new artifact with optional title and body.
  /// Returns the new artifact's ID.
  Future<String> createArtifact(String? title, String? body) async {
    final dek = ArtifactEncryption.generateDataEncryptionKey();
    final artifactEncryption = ArtifactEncryption(dek);
    final encryptedDek = await encryption.encryptEncryptionKey(dek);
    final encryptedDekB64 =
        Base64Utils.encode(encryptedDek, Encoding.base64);
    final encryptedHeader = await artifactEncryption
        .encryptHeader({'title': title});
    final encryptedBody = await artifactEncryption
        .encryptBody({'body': body ?? ''});
    final artifactId = encryption.generateId();
    final request = ArtifactCreateRequest(
      id: artifactId,
      header: encryptedHeader,
      body: encryptedBody,
      dataEncryptionKey: encryptedDekB64,
    );
    final response = await ApiClient().post(
      '/v1/artifacts',
      data: request.toJson(),
    );
    if (!ApiClient().isSuccess(response)) {
      throw StateError(
        'Failed to create artifact: ${response.statusCode}',
      );
    }
    _artifactDataKeys[artifactId] = dek;
    artifactsSync.invalidate();
    return artifactId;
  }

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(
    String id,
    String? title,
    String? body,
  ) async {
    final dek = _artifactDataKeys[id];
    if (dek == null) {
      throw StateError('No decryption key found for artifact $id');
    }
    final artifactEncryption = ArtifactEncryption(dek);
    final existing = _artifacts.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Artifact $id not found in cache'),
    );
    final encryptedHeader = await artifactEncryption
        .encryptHeader({'title': title});
    final encryptedBody = await artifactEncryption
        .encryptBody({'body': body ?? ''});
    final request = ArtifactUpdateRequest(
      header: encryptedHeader,
      expectedHeaderVersion: existing.headerVersion,
      body: encryptedBody,
      expectedBodyVersion: existing.bodyVersion,
    );
    final response = await ApiClient().post(
      '/v1/artifacts/$id',
      data: request.toJson(),
    );
    if (!ApiClient().isSuccess(response)) {
      throw StateError(
        'Failed to update artifact: ${response.statusCode}',
      );
    }
    artifactsSync.invalidate();
  }

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) async {
    final response = await ApiClient().delete('/v1/artifacts/$id');
    if (!ApiClient().isSuccess(response)) {
      throw StateError(
        'Failed to delete artifact: ${response.statusCode}',
      );
    }
    _artifactDataKeys.remove(id);
    _artifacts.removeWhere((a) => a.id == id);
    _notifyDataChanged();
  }

  /// Fetch friends list from server
  Future<void> fetchFriends() async {
    if (kDebugMode) debugPrint('Fetching friends...');
    try {
      final response = await ApiClient().get('/v1/friends');
      if (!ApiClient().isSuccess(response)) {
        if (kDebugMode) {
          debugPrint(
            'Failed to fetch friends: ${response.statusCode}',
          );
        }
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

      if (kDebugMode) {
        debugPrint(
          'Fetched friends: ${_friends.length}, '
          'pending requests: ${_friendRequests.length}',
        );
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to fetch friends: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch friend requests from server.
  /// Friends and requests are both returned by fetchFriends() from /v1/friends,
  /// so this is a no-op to avoid a double network request.
  Future<void> fetchFriendRequests() async {}

  /// Fetch feed items from server
  Future<void> fetchFeed() async {
    if (kDebugMode) debugPrint('Fetching feed...');
    try {
      final response = await ApiClient().get(
        '/v1/feed',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      if (!ApiClient().isSuccess(response)) {
        if (kDebugMode) {
          debugPrint('Failed to fetch feed: ${response.statusCode}');
        }
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
      if (kDebugMode) {
        debugPrint('Fetched feed items: ${_feedItems.length}');
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to fetch feed: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch todos from server
  Future<void> fetchTodos() async {
    if (kDebugMode) debugPrint('Fetching todos...');
    try {
      final items = await KvApi().getByPrefix('todo.', limit: 1000);
      final decryptedByKey = <String, Map<String, dynamic>>{};

      final results = await Future.wait(
        items.map((item) async {
          try {
            final decrypted =
                await encryption.decryptRaw(item.value);
            if (decrypted is Map<String, dynamic>) {
              return MapEntry(item.key, decrypted);
            }
          } catch (error) {
            if (kDebugMode) {
              debugPrint(
                'Failed to decrypt todo item'
                ' ${item.key}: $error',
              );
            }
          }
          return null;
        }),
      );
      for (final entry in results) {
        if (entry != null) {
          decryptedByKey[entry.key] = entry.value;
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
      if (kDebugMode) {
        debugPrint(
          'Fetched todos: ${parsedTodoLists.length} list(s),'
          ' $totalItems item(s)',
        );
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to fetch todos: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch session git status from server
  /// Git status is managed locally and updated via socket events
  Future<void> _fetchSessionGitStatus() async {
    // Git status is currently managed locally via the provider
    // This sync can be extended to fetch from server when needed
    if (kDebugMode) debugPrint('Session git status sync triggered');
  }

  @visibleForTesting
  Map<String?, TodoList> parseTodoListsFromDecryptedKv(
    Map<String, Map<String, dynamic>> decryptedByKey,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final todosById = <String, TodoItem>{};
    var undoneOrder = <String>[];
    var doneOrder = <String>[];

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
    var sessionId = raw['sessionId'] as String?;
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
    final id = (raw['id'] as String?) ??
        (raw['uid'] as String?) ??
        'unknown';
    final firstName = (raw['firstName'] as String?) ?? '';
    final lastName = raw['lastName'] as String?;
    final username = (raw['username'] as String?) ?? '';
    final avatarRaw = raw['avatar'];
    AvatarRef? avatar;
    if (avatarRaw is Map<String, dynamic>) {
      avatar = AvatarRef.fromJson(avatarRaw);
    }

    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      avatar: avatar,
      bio: raw['bio'] as String?,
      status: RelationshipStatus.fromString(
        raw['status'] as String? ?? 'none',
      ),
    );
  }

  List<FriendRequest> _deriveFriendRequests(List<UserProfile> profiles) {
    return profiles
        .where(
            (profile) => profile.status == RelationshipStatus.pending,
        )
        .map((profile) => FriendRequest(
              id: 'friend-request-${profile.id}',
              fromUserId: profile.id,
              fromUserName: profile.name ?? profile.id,
              fromUserAvatarUrl: profile.avatarUrl,
              toUserId: serverID,
              createdAt: 0,
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
    final kind = bodyMap['kind'] as String? ?? 'text';
    var userId = raw['userId'] as String? ?? 'system';

    // Derive userId from uid in body for relationship events
    if (kind == 'friend_request' || kind == 'friend_accepted') {
      userId = (bodyMap['uid'] as String?) ?? userId;
    }

    final body = FeedBody(
      kind: kind,
      uid: bodyMap['uid'] as String?,
      text: bodyMap['text'] as String?,
    );

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
      repeatKey: raw['repeatKey'] as String?,
      cursor: raw['cursor'] as String?,
      counter: raw['counter'] as int?,
    );
  }

  /// Sync settings with server
  Future<void> syncSettings() async {
    if (kDebugMode) debugPrint('Syncing settings...');

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
        );

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
          _notifyDataChanged();
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
            _settingsVersion =
                _asInt(data['settingsVersion']) ?? _settingsVersion;
          }
        } else {
          _settingsSnapshot = Settings();
          _settingsVersion =
              _asInt(data['settingsVersion']) ?? _settingsVersion;
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'Failed to fetch settings: ${response.statusCode}',
          );
        }
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Error syncing settings: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Sync purchases with RevenueCat
  Future<void> syncPurchases() async {
    if (kDebugMode) debugPrint('Syncing purchases...');
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/account/profile');
      if (!apiClient.isSuccess(response)) {
        return;
      }

      final data = response.data as Map<String, dynamic>?;
      _purchases = Purchases.parse(data?['purchases']);
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to sync purchases: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch profile from server
  Future<void> fetchProfile() async {
    if (kDebugMode) debugPrint('Fetching profile...');

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get('/v1/account/profile');

      if (apiClient.isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        _profile = Profile.fromJson(data);
      } else {
        if (kDebugMode) {
          debugPrint(
            'Failed to fetch profile: ${response.statusCode}',
          );
        }
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Error fetching profile: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch native app update status
  Future<void> fetchNativeUpdate() async {
    if (kDebugMode) debugPrint('Fetching native update...');
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
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to fetch native update: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
      _nativeUpdateUrl = null;
    }
  }

  /// Register or refresh device push token
  Future<void> syncPushToken() async {
    if (kDebugMode) debugPrint('Syncing push token...');
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
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Failed to sync push token: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Refresh machines from server
  Future<void> refreshMachines() async {
    // Route through machinesSync so concurrent calls are coalesced rather than
    // firing two parallel GET /v1/machines requests.
    await machinesSync.invalidateAndAwait();
  }

  /// Refresh sessions from server
  Future<void> refreshSessions() async {
    await sessionsSync.invalidateAndAwait();
  }

  /// Refresh friends and pending requests from server.
  Future<void> refreshFriends() async {
    await friendsSync.invalidateAndAwait();
    // friendRequestsSync is a no-op (requests come with friends).
  }

  /// Refresh feed items from server.
  Future<void> refreshFeed() async {
    await feedSync.invalidateAndAwait();
  }

  /// Delete a session.
  Future<bool> deleteSession(String sessionId) async {
    try {
      final response = await ApiClient().delete('/v1/sessions/$sessionId');
      if (!ApiClient().isSuccess(response)) {
        return false;
      }

      _handleDeleteSession(<String, dynamic>{'sid': sessionId});
      return true;
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Failed to delete session $sessionId: $error');
      }
      unawaited(Sentry.captureException(error, stackTrace: stack));
      return false;
    }
  }

  /// Create a session on a target machine/path and return the new session ID.
  ///
  /// Sends a `spawn-happy-session` RPC to the machine daemon, which starts a
  /// new Claude Code agent in [path].  If the directory does not yet exist the
  /// daemon returns a `requestToApproveDirectoryCreation` result; passing
  /// [approvedNewDirectoryCreation] = true tells it to create the directory.
  ///
  /// The active profile's environment variables (API keys, model config, etc.)
  /// and the last-used agent type are automatically read from settings and
  /// forwarded to the daemon so it can configure the agent correctly.
  ///
  /// Throws a [StateError] with a human-readable message on failure.
  Future<String> createSession({
    required String machineId,
    required String path,
    bool approvedNewDirectoryCreation = false,
  }) async {
    if (!isInitialized) {
      throw StateError('Sync is not initialized');
    }
    if (socketIoClient.connectionStatus != ConnectionStatus.connected) {
      throw StateError('Not connected to server');
    }

    // Derive agent type and environment variables from the active profile.
    final profileId = _settingsSnapshot.lastUsedProfile;
    final profile = profileId != null
        ? _resolveProfile(profileId)
        : _settingsSnapshot.profiles.firstOrNull;
    final envVars = profile != null
        ? _profileEnvironmentVariables(profile)
        : <String, String>{};
    final agent = _settingsSnapshot.lastUsedAgent;
    final startupScript = profile?.startupBashScript;
    final permissionMode = _settingsSnapshot.lastUsedPermissionMode;

    final req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: path,
      approvedNewDirectoryCreation: approvedNewDirectoryCreation,
      agent: agent,
      environmentVariables: envVars.isNotEmpty ? envVars : null,
      startupBashScript: startupScript,
      permissionMode: permissionMode,
    );

    final result = await _typedMachineRPC(
      machineId,
      'spawn-happy-session',
      req.toJson(),
      SpawnSessionResponse.fromJson,
    );

    if (result.type == 'success') {
      final sessionId = result.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw StateError('Machine returned empty session ID');
      }

      // Initialize encryption from the DEK included in the spawn response,
      // avoiding the sync race condition where delta fetches miss the new
      // session's dataEncryptionKey.
      final dek = result.dataEncryptionKey;
      if (dek != null && dek.isNotEmpty) {
        final decryptedKey = await encryption.decryptEncryptionKey(dek);
        if (decryptedKey != null) {
          await encryption.initializeSessions({sessionId: decryptedKey});
        }
      }

      // Force a full fetch (not delta) to ensure the newly created session
      // is included in the results. This prevents a race condition where
      // server clock skew causes the session to be excluded from delta
      // fetches (changedSince > session.updatedAt).
      _forceFullFetchNext = true;
      await refreshSessions();

      return sessionId;
    }

    if (result.type == 'requestToApproveDirectoryCreation') {
      return createSession(
        machineId: machineId,
        path: path,
        approvedNewDirectoryCreation: true,
      );
    }

    throw StateError(result.errorMessage ?? 'unknown error');
  }

  /// Execute a bash command on a machine.
  Future<BashResponse> machineBash({
    required String machineId,
    required String command,
    required String cwd,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'bash',
        BashRequest(command: command, cwd: cwd).toJson(),
        BashResponse.fromJson,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('machineBash error: $error');
    }
    return const BashResponse(
      success: false,
      stderr: 'RPC call failed',
    );
  }

  /// Create a git worktree on a machine under `.dev/worktree/<name>` relative
  /// to [basePath] and return the absolute path to the new worktree.
  ///
  /// Mirrors React Native's `createWorktree` utility.
  /// Throws [StateError] if [basePath] is not a git repository or the
  /// worktree creation fails after retries.
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) async {
    final gitCheck = await machineBash(
      machineId: machineId,
      command: 'git rev-parse --git-dir',
      cwd: basePath,
    );
    if (!gitCheck.success) {
      throw StateError('Not a Git repository');
    }

    final name = _generateWorktreeName();
    final worktreePath = '.dev/worktree/$name';
    var result = await machineBash(
      machineId: machineId,
      command: 'git worktree add -b $name $worktreePath',
      cwd: basePath,
    );
    if (result.success) {
      return '$basePath/$worktreePath';
    }

    if (result.stderr.contains('already exists')) {
      for (var i = 2; i <= 4; i++) {
        final newName = '$name-$i';
        final newPath = '.dev/worktree/$newName';
        result = await machineBash(
          machineId: machineId,
          command: 'git worktree add -b $newName $newPath',
          cwd: basePath,
        );
        if (result.success) {
          return '$basePath/$newPath';
        }
      }
    }

    throw StateError(
      result.stderr.isNotEmpty ? result.stderr : 'Failed to create worktree',
    );
  }

  static const _worktreeAdjectives = [
    'clever', 'happy', 'swift', 'bright', 'calm',
    'bold', 'quiet', 'brave', 'wise', 'eager',
    'gentle', 'quick', 'sharp', 'smooth', 'fresh',
  ];

  static const _worktreeNouns = [
    'ocean', 'forest', 'cloud', 'star', 'river',
    'mountain', 'valley', 'bridge', 'beacon', 'harbor',
    'garden', 'meadow', 'canyon', 'island', 'desert',
  ];

  String _generateWorktreeName() {
    final rand = Random();
    final adj =
        _worktreeAdjectives[rand.nextInt(_worktreeAdjectives.length)];
    final noun = _worktreeNouns[rand.nextInt(_worktreeNouns.length)];
    return '$adj-$noun';
  }

  /// Convert an [AIBackendProfile] into a flat map of environment variables
  /// that will be forwarded to the machine daemon when spawning a session.
  ///
  /// Resolve a profile by ID: custom profiles first, then built-in.
  AIBackendProfile? _resolveProfile(String id) {
    for (final p in _settingsSnapshot.profiles) {
      if (p.id == id) return p;
    }
    return getBuiltInProfile(id);
  }

  /// Mirrors React Native's `getProfileEnvironmentVariables` in settings.ts.
  Map<String, String> _profileEnvironmentVariables(
    AIBackendProfile profile,
  ) {
    final envVars = <String, String>{};

    for (final v in profile.environmentVariables) {
      envVars[v.name] = v.value;
    }

    final anthropic = profile.anthropicConfig;
    if (anthropic != null) {
      if (anthropic.baseUrl != null) {
        envVars['ANTHROPIC_BASE_URL'] = anthropic.baseUrl!;
      }
      if (anthropic.authToken != null) {
        envVars['ANTHROPIC_AUTH_TOKEN'] = anthropic.authToken!;
      }
      if (anthropic.model != null) {
        envVars['ANTHROPIC_MODEL'] = anthropic.model!;
      }
    }

    final openai = profile.openaiConfig;
    if (openai != null) {
      if (openai.apiKey != null) {
        envVars['OPENAI_API_KEY'] = openai.apiKey!;
      }
      if (openai.baseUrl != null) {
        envVars['OPENAI_BASE_URL'] = openai.baseUrl!;
      }
      if (openai.model != null) {
        envVars['OPENAI_MODEL'] = openai.model!;
      }
    }

    final azure = profile.azureOpenAIConfig;
    if (azure != null) {
      if (azure.apiKey != null) {
        envVars['AZURE_OPENAI_API_KEY'] = azure.apiKey!;
      }
      if (azure.endpoint != null) {
        envVars['AZURE_OPENAI_ENDPOINT'] = azure.endpoint!;
      }
      if (azure.apiVersion != null) {
        envVars['AZURE_OPENAI_API_VERSION'] = azure.apiVersion!;
      }
      if (azure.deploymentName != null) {
        envVars['AZURE_OPENAI_DEPLOYMENT_NAME'] = azure.deploymentName!;
      }
    }

    final together = profile.togetherAIConfig;
    if (together != null) {
      if (together.apiKey != null) {
        envVars['TOGETHER_API_KEY'] = together.apiKey!;
      }
      if (together.model != null) {
        envVars['TOGETHER_MODEL'] = together.model!;
      }
    }

    final tmux = profile.tmuxConfig;
    if (tmux != null) {
      if (tmux.sessionName != null) {
        envVars['TMUX_SESSION_NAME'] = tmux.sessionName!;
      }
      if (tmux.tmpDir != null) {
        envVars['TMUX_TMPDIR'] = tmux.tmpDir!;
      }
      if (tmux.updateEnvironment != null) {
        envVars['TMUX_UPDATE_ENVIRONMENT'] =
            tmux.updateEnvironment.toString();
      }
    }

    return envVars;
  }

  /// Send message to session
  Future<void> sendMessage(
    String sessionId,
    String text, {
    String? displayText,
    String? permissionMode,
    String? modelMode,
  }) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      // Encryption may not be initialized yet if a new-session event arrived
      // but fetchSessions() hasn't completed. Wait for the pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Last resort: force a full (non-delta) fetch to bypass any
        // changedSince race that may have caused the session to be skipped.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError(
          'Session encryption not initialized for $sessionId',
        );
      }
    }

    var session = _sessions[sessionId];
    if (session == null) {
      // Retry: the session may not be in _sessions due to the changedSince
      // delta-fetch race. Use _forceFullFetchNext flag (not _lastSessionsFetchedAt
      // = null) to avoid TOCTOU: a concurrent fetch completing can overwrite
      // _lastSessionsFetchedAt before the forced fetch reads it.
      _forceFullFetchNext = true;
      await sessionsSync.invalidateAndAwait();
      session = _sessions[sessionId];
    }
    if (session == null) {
      throw StateError('Session $sessionId not loaded');
    }

    final effectivePermissionMode =
        permissionMode ?? session.permissionMode ?? 'default';
    final flavor = session.metadata?.flavor;
    final isGemini = flavor == 'gemini';
    final effectiveModelMode = modelMode ??
        session.modelMode ??
        (isGemini ? 'gemini-2.5-pro' : 'default');
    final localId = encryption.generateId();
    final sentFrom = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'mac',
      _ => 'web',
    };
    final model = effectiveModelMode != 'default' ? effectiveModelMode : null;

    final rawRecord = <String, dynamic>{
      'role': 'user',
      'content': <String, dynamic>{
        'type': 'text',
        'text': text,
      },
      'meta': <String, dynamic>{
        'sentFrom': sentFrom,
        'permissionMode': effectivePermissionMode,
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

    // Auto-restore: if the session's agent is offline but the machine is
    // reachable, spawn a new agent so the message can be delivered.
    // Skip if the session's lifecycleState is 'starting' or 'running' —
    // the daemon just created it and the agent hasn't sent its first keep-alive
    // yet, so presence appears offline even though the process is live.
    final lifecycleState = session.metadata?.lifecycleState;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    if (!session.isOnline && !agentIsStartingOrRunning) {
      final machineId = session.metadata?.machineId;
      final path = session.metadata?.path;
      if (machineId != null &&
          machineId.isNotEmpty &&
          path != null &&
          path.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'Session $sessionId is offline (lifecycleState=$lifecycleState), '
            'attempting auto-restore on machine $machineId at $path',
          );
        }
        try {
          final req = SpawnSessionRequest(
            type: 'spawn-in-directory',
            directory: path,
            sessionId: sessionId,
            agent: session.metadata?.flavor ?? 'claude',
            permissionMode: effectivePermissionMode,
          );
          await _typedMachineRPC(
            machineId,
            'spawn-happy-session',
            req.toJson(),
            SpawnSessionResponse.fromJson,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Auto-restore failed for $sessionId: $e');
          }
        }
      }
    }

    final ready = await waitForAgentReady(sessionId);
    if (!ready) {
      if (kDebugMode) {
        debugPrint(
          'Session $sessionId not marked ready after timeout,'
          ' sending anyway',
        );
      }
    }

    final apiClient = ApiClient();
    var sent = false;
    try {
      final response = await apiClient.post(
        '/v3/sessions/$sessionId/messages',
        data: {
          'messages': [
            {
              'content': encryptedRawRecord,
              'localId': localId,
            },
          ],
        },
      );

      if (apiClient.isSuccess(response)) {
        sent = true;
        final data = response.data as Map<String, dynamic>?;
        final serverMessages = (data?['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        if (serverMessages.isNotEmpty) {
          final serverMsg = serverMessages.first;
          _upsertSessionMessages(sessionId, [
            {
              'id': serverMsg['id'] as String,
              'localId': localId,
              'seq': serverMsg['seq'] as int,
              'createdAt': serverMsg['createdAt'] as int,
              'role': 'user',
              'kind': 'text',
              'content': text,
              'raw': rawRecord,
            },
          ]);
        }
      } else {
        throw StateError(
          'Failed to send message: ${response.statusCode}',
        );
      }
    } finally {
      if (!sent) _removeOptimisticMessage(sessionId, localId);
    }
  }

  void _removeOptimisticMessage(String sessionId, String localId) {
    final msgs = _sessionMessages[sessionId];
    if (msgs != null) {
      _sessionMessages[sessionId] =
          msgs.where((m) => m['id'] != localId).toList();
      _sessionMessagesCache = null;
    }
  }

  /// RPC call for machines - uses machine-specific encryption.
  Future<dynamic> machineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params,
  ) async {
    final machineEncryption = encryption.getMachineEncryption(machineId);
    if (machineEncryption == null) {
      throw StateError(
        'Machine encryption not found for $machineId',
      );
    }

    final encrypted = await machineEncryption.encryptRaw(params);
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$machineId:$method',
      'params': encrypted,
    });

    if (result is Map && result['ok'] == true) {
      final decrypted = await machineEncryption.decryptRaw(
        result['result'] as String,
      );
      return decrypted;
    }
    throw StateError('Machine RPC call failed');
  }

  /// RPC call for sessions - uses session-specific encryption.
  Future<dynamic> sessionRPC(
    String sessionId,
    String method,
    Map<String, dynamic> params,
  ) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError(
          'Session encryption not found for $sessionId',
        );
      }
    }

    final encrypted = await sessionEncryption.encryptRaw(params);
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$sessionId:$method',
      'params': encrypted,
    });

    if (result is Map && result['ok'] == true) {
      final decrypted = await sessionEncryption.decryptRaw(
        result['result'] as String,
      );
      return decrypted;
    }
    throw StateError('RPC call failed');
  }

  /// Typed wrapper around [machineRPC] that deserialises the response.
  Future<Resp> _typedMachineRPC<Resp>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await machineRPC(machineId, method, params);
    return fromJson(raw as Map<String, dynamic>);
  }

  /// Typed wrapper around [sessionRPC] that deserialises the response.
  Future<Resp> _typedSessionRPC<Resp>(
    String sessionId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await sessionRPC(sessionId, method, params);
    return fromJson(raw as Map<String, dynamic>);
  }

  /// Allow a permission request for a session.
  Future<void> sessionAllow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
  }) async {
    await _typedSessionRPC(
      sessionId,
      'permission',
      PermissionRequest(
        id: permissionId,
        approved: true,
        mode: mode,
        allowTools: allowTools,
        decision: decision,
      ).toJson(),
      PermissionResponse.fromJson,
    );
  }

  /// Deny a permission request for a session.
  Future<void> sessionDeny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) async {
    await _typedSessionRPC(
      sessionId,
      'permission',
      PermissionRequest(
        id: permissionId,
        approved: false,
        decision: decision,
      ).toJson(),
      PermissionResponse.fromJson,
    );
  }

  /// Kill a session's agent process.
  Future<KillSessionResponse> killSession(String sessionId) async {
    return _typedSessionRPC(
      sessionId,
      'killSession',
      const {},
      KillSessionResponse.fromJson,
    );
  }

  /// Abort the current agent turn without killing the session.
  Future<AbortResponse> abortSession(
    String sessionId, {
    String reason = '',
  }) async {
    return _typedSessionRPC(
      sessionId,
      'abort',
      {'reason': reason},
      AbortResponse.fromJson,
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
    _visibleSessionId = sessionId;
    if (!messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] =
          InvalidateSync(() => fetchMessages(sessionId));
    }
    messagesSync[sessionId]?.invalidate();
  }

  /// Fetch messages for a session.
  ///
  /// On first open (no entry in [_sessionLastSeq]) this uses the session's
  /// [Session.lastSeq] hint to jump straight to the tail of the history,
  /// fetching only the most recent [initialLoad] messages.  Subsequent calls
  /// (incremental delta syncs) continue from [_sessionLastSeq] as before.
  Future<void> fetchMessages(String sessionId) async {
    if (kDebugMode) {
      debugPrint('Fetching messages for session: $sessionId');
    }

    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        if (kDebugMode) {
          debugPrint(
            'Session encryption not initialized for $sessionId, skipping fetch',
          );
        }
        return;
      }
    }

    try {
      final apiClient = ApiClient();
      // "First load" means no messages are in memory yet for this session
      // (new session or app was restarted — _sessionMessages is not
      // persisted to disk).  In this case we do a tail-load using the
      // server's lastSeq hint regardless of the persisted _sessionLastSeq.
      final isFirstLoad = !_sessionMessages.containsKey(sessionId) ||
          (_sessionMessages[sessionId]?.isEmpty ?? true);
      int afterSeq;

      if (isFirstLoad) {
        // Lazy tail-load: start near the end of the session history so we
        // don't download thousands of messages that the UI will never show.
        final session = _sessions[sessionId];
        final serverLastSeq = session?.lastSeq;
        if (serverLastSeq != null && serverLastSeq > initialLoad) {
          afterSeq = serverLastSeq - initialLoad;
          // Record where we started so the UI can offer "load older" later.
          _sessionFirstLoadedSeq[sessionId] = afterSeq + 1;
        } else {
          afterSeq = 0;
          // Session is short — we will load everything; no older messages.
          _sessionFirstLoadedSeq[sessionId] = 0;
        }
        MMKVStorage().saveSessionFirstLoadedSeq(
          Map.unmodifiable(_sessionFirstLoadedSeq),
        );
      } else {
        afterSeq = _sessionLastSeq[sessionId]!;
      }

      var page = 0;
      while (true) {
        // ── Check visibility BEFORE network call ──
        if (page > 0 && _visibleSessionId != sessionId) {
          if (kDebugMode) {
            debugPrint(
              '[fetchMessages] $sessionId no longer visible '
              'after page $page — aborting',
            );
          }
          unawaited(Sentry.captureMessage(
            'fetchMessages aborted — session not visible',
            level: SentryLevel.info,
            params: [
              'sessionId=$sessionId',
              'page=$page',
              'afterSeq=$afterSeq',
            ],
          ));
          break;
        }

        final fetchStart = Stopwatch()..start();
        final response = await apiClient.get(
          '/v3/sessions/$sessionId/messages',
          queryParameters: {'after_seq': afterSeq, 'limit': 100},
        );
        final fetchMs = fetchStart.elapsedMilliseconds;

        if (!apiClient.isSuccess(response)) {
          if (kDebugMode) {
            debugPrint(
              'Failed to fetch messages: ${response.statusCode}',
            );
          }
          break;
        }

        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final hasMore = data['hasMore'] as bool? ?? false;

        unawaited(Sentry.captureMessage(
          'fetchMessages page $page',
          level: SentryLevel.info,
          params: [
            'sessionId=$sessionId',
            'msgs=${messages.length}',
            'hasMore=$hasMore',
            'afterSeq=$afterSeq',
            'fetchMs=$fetchMs',
          ],
        ));

        if (kDebugMode) {
          debugPrint(
            '[fetchMessages] $sessionId page=$page '
            'msgs=${messages.length} hasMore=$hasMore '
            'fetchMs=$fetchMs',
          );
        }

        // ── Decrypt + process (isolate for large batches) ──
        final decryptStart = Stopwatch()..start();
        final processed =
            await sessionEncryption.decryptAndProcessMessages(
          messages,
          sessionId,
        );
        final decryptMs = decryptStart.elapsedMilliseconds;

        // ── Yield before main-thread merge/group work ──
        await Future<void>.delayed(Duration.zero);

        // ── Upsert messages ──
        final existingCount =
            _sessionMessages[sessionId]?.length ?? 0;
        final upsertStart = Stopwatch()..start();
        if (processed.messages.isNotEmpty) {
          _upsertSessionMessages(sessionId, processed.messages);
        }
        final upsertMs = upsertStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply tool results + usage ──
        final toolStart = Stopwatch()..start();
        if (processed.toolResults.isNotEmpty) {
          _applyToolResults(sessionId, processed.toolResults);
        }
        for (final u in processed.usageUpdates) {
          _updateSessionUsage(
            u['sessionId'] as String,
            u['usage'] as Map<String, dynamic>,
            u['timestamp'] as int,
          );
        }
        final toolMs = toolStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Group sidechain messages ──
        final groupStart = Stopwatch()..start();
        _groupSidechainMessages(sessionId);
        final groupMs = groupStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply permission requests ──
        final permStart = Stopwatch()..start();
        _applyPermissionRequests(sessionId);
        final permMs = permStart.elapsedMilliseconds;

        final mergeMs =
            upsertMs + toolMs + groupMs + permMs;

        if (processed.maxSeq > afterSeq) {
          afterSeq = processed.maxSeq;
        }
        _sessionLastSeq[sessionId] = afterSeq;
        // Debounced: batches rapid page fetches into a single disk write
        // instead of blocking the main thread with jsonEncode + MMKV I/O
        // on every pagination page.
        _scheduleSaveSeq();

        unawaited(Sentry.captureMessage(
          'fetchMessages page $page done',
          level: SentryLevel.info,
          params: [
            'sessionId=$sessionId',
            'existing=$existingCount',
            'newMsgs=${processed.messages.length}',
            'decryptMs=$decryptMs',
            'upsertMs=$upsertMs',
            'toolMs=$toolMs',
            'groupMs=$groupMs',
            'permMs=$permMs',
            'mergeMs=$mergeMs',
          ],
        ));

        if (kDebugMode) {
          debugPrint(
            '[fetchMessages] $sessionId page=$page '
            'decryptMs=$decryptMs '
            'upsert=$upsertMs tool=$toolMs '
            'group=$groupMs perm=$permMs',
          );
        }

        if (!hasMore) break;
        page++;

        // ── Yield between pages ──
        await Future<void>.delayed(Duration.zero);
      }
      if (!_sessionMessageChangeController.isClosed) {
        _sessionMessageChangeController.add(sessionId);
      }
      _notifyDataChanged();
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Error fetching messages: $error');
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  }

  /// Fetch the page of messages that precedes what has already been loaded
  /// for [sessionId].  Call [hasOlderMessages] first to guard against
  /// unnecessary requests.
  Future<void> fetchOlderMessages(String sessionId) async {
    if (isLoadingOlderMessages(sessionId)) return;
    final firstLoaded = _sessionFirstLoadedSeq[sessionId] ?? 0;
    if (firstLoaded <= 1) return; // nothing older to fetch

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) return;

    _loadingOlderMessages.add(sessionId);
    _notifyDataChanged();

    try {
      const pageSize = 100;
      final startSeq =
          (firstLoaded - 1 - pageSize).clamp(0, firstLoaded - 1);

      final apiClient = ApiClient();
      final response = await apiClient.get(
        '/v3/sessions/$sessionId/messages',
        queryParameters: {
          'after_seq': startSeq,
          'limit': pageSize,
        },
      );

      if (!apiClient.isSuccess(response)) {
        if (kDebugMode) {
          debugPrint(
            'Failed to fetch older messages: ${response.statusCode}',
          );
        }
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (kDebugMode) {
        debugPrint(
          '[fetchOlderMessages] $sessionId '
          'msgs=${messages.length}',
        );
      }

      final processed =
          await sessionEncryption.decryptAndProcessMessages(
        messages,
        sessionId,
      );

      // Yield before main-thread merge work
      await Future<void>.delayed(Duration.zero);

      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
      }
      for (final u in processed.usageUpdates) {
        _updateSessionUsage(
          u['sessionId'] as String,
          u['usage'] as Map<String, dynamic>,
          u['timestamp'] as int,
        );
      }
      _groupSidechainMessages(sessionId);
      _applyPermissionRequests(sessionId);

      // Move the lower boundary back to cover the page we just fetched.
      _sessionFirstLoadedSeq[sessionId] =
          startSeq == 0 ? 0 : startSeq + 1;
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );

      if (!_sessionMessageChangeController.isClosed) {
        _sessionMessageChangeController.add(sessionId);
      }
      _notifyDataChanged();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Error fetching older messages: $error');
      }
      unawaited(Sentry.captureException(error, stackTrace: stack));
    } finally {
      _loadingOlderMessages.remove(sessionId);
      _notifyDataChanged();
    }
  }

  /// Wait for agent to be ready
  Future<bool> waitForAgentReady(
    String sessionId, [
    int timeoutMs = sessionReadyTimeoutMs,
  ]) async {
    final timeoutAt = DateTime.now().millisecondsSinceEpoch + timeoutMs;
    while (DateTime.now().millisecondsSinceEpoch < timeoutAt) {
      final session = _sessions[sessionId];
      // Consider the session ready if:
      // 1. agentStateVersion > 0 (permission request or agent state set), OR
      // 2. presence is 'online' (Go's session-alive keep-alives arrived, meaning
      //    the daemon is running and connected — typically within 2 seconds).
      if (session != null &&
          (session.agentStateVersion > 0 || session.isOnline)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// Process a decrypted message into display messages and tool results.
  /// Test helper for [_processDecryptedMessage].
  @visibleForTesting
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  testProcessDecryptedMessage({
    required String id,
    required int seq,
    required String sessionId,
    required Map<String, dynamic> content,
    String? localId,
    int? createdAtMs,
  }) {
    return _processDecryptedMessage(
      DecryptedMessage(
        id: id,
        seq: seq,
        localId: localId,
        content: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      sessionId,
    );
  }

  ///
  /// Returns a tuple of (displayMessages, toolResults).
  /// Display messages are added to the session message list.
  /// Tool results are used to update existing tool-call message states.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processDecryptedMessage(DecryptedMessage message, String sessionId) {
    final createdAt = message.createdAt.millisecondsSinceEpoch;
    final content = message.content;

    if (content is! Map<String, dynamic>) {
      // Fallback for non-map content
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'kind': 'text',
            'content': content?.toString() ?? '',
            'raw': content,
          },
        ],
        [],
      );
    }

    final role = content['role'] as String?;
    final nestedContent = content['content'];

    // User messages: {role: 'user', content: {type: 'text', text: '...'}}
    if (role == 'user') {
      if (nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text') {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'user',
              'kind': 'text',
              'content': nestedContent['text']?.toString() ?? '',
              'raw': content,
            },
          ],
          [],
        );
      }
      // Fallback for non-text user messages
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'user',
            'kind': 'text',
            'content': content.toString(),
            'raw': content,
          },
        ],
        [],
      );
    }

    // Agent messages: {role: 'agent', content: {type: ..., data: ...}}
    if (role == 'agent') {
      if (nestedContent is! Map<String, dynamic>) {
        return (
          [
            {
              'id': 'error-${message.id}_parse',
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'system',
              'kind': 'error',
              'errorType': 'agent_content_not_map',
              'errorMessage': 'Agent message content is not '
                  'a valid structure',
              'debugData': {
                'messageId': message.id,
                'seq': message.seq,
                'contentType': '${nestedContent.runtimeType}',
              },
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      final contentType = nestedContent['type'] as String?;

      // Output type: Claude/assistant messages
      if (contentType == 'output') {
        return _processOutputContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // Event type: mode switches, limit reached, etc.
      if (contentType == 'event') {
        return _processEventContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      // Codex type: Codex agent messages
      if (contentType == 'codex') {
        return _processCodexContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      // ACP type: unified agent communication protocol
      if (contentType == 'acp') {
        return _processAcpContent(message, nestedContent, createdAt, content);
      }
    }

    return (
      [
        {
          'id': 'error-${message.id}_parse',
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'system',
          'kind': 'error',
          'errorType': 'unknown_role',
          'errorMessage': 'Unrecognized message role: $role',
          'debugData': {
            'messageId': message.id,
            'seq': message.seq,
            'role': role,
          },
        },
      ],
      <Map<String, dynamic>>[],
    );
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processOutputContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip meta and compact summary messages
    if (data['isMeta'] == true || data['isCompactSummary'] == true) {
      return ([], []);
    }

    // Sidechain metadata for sub-agent grouping
    final isSidechain = data['isSidechain'] == true;
    final dataUuid = data['uuid'] as String?;
    final dataParentUuid = data['parentUuid'] as String?;

    final dataType = data['type'] as String?;

    if (dataType == 'assistant') {
      final agentMsg = data['message'];
      if (agentMsg is! Map<String, dynamic>) return ([], []);

      // Extract usage data for context window tracking
      final usageData = agentMsg['usage'] as Map<String, dynamic>?;
      if (usageData != null) {
        _updateSessionUsage(sessionId, usageData, createdAt);
      }

      final agentContentList = agentMsg['content'];
      if (agentContentList is! List) return ([], []);

      final results = <Map<String, dynamic>>[];
      var i = 0;
      for (final c in agentContentList) {
        if (c is! Map<String, dynamic>) {
          i++;
          continue;
        }
        final type = c['type'] as String?;

        if (type == 'text') {
          results.add({
            'id': '${message.id}_t$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': c['text']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (dataUuid != null) 'uuid': dataUuid,
            if (dataParentUuid != null)
              'parentUuid': dataParentUuid,
          });
        } else if (type == 'thinking') {
          results.add({
            'id': '${message.id}_k$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${c['thinking']}*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (dataUuid != null) 'uuid': dataUuid,
            if (dataParentUuid != null)
              'parentUuid': dataParentUuid,
          });
        } else if (type == 'tool_use') {
          results.add({
            'id': '${message.id}_u$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': c['name'],
            'input': c['input'],
            'toolUseId': c['id'],
            'state': 'running',
            'content': c,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (dataUuid != null) 'uuid': dataUuid,
            if (dataParentUuid != null)
              'parentUuid': dataParentUuid,
          });
        }
        i++;
      }
      return (results, []);
    }

    if (dataType == 'user') {
      // Sidechain root: isSidechain=true, message.content is
      // a string (the prompt sent to the sub-agent). We emit a
      // hidden marker so _groupSidechainMessages can match it.
      if (isSidechain) {
        final msgContent = data['message']?['content'];
        if (msgContent is String) {
          return (
            [
              {
                'id': '${message.id}_sc',
                'seq': message.seq,
                'createdAt': createdAt,
                'kind': 'sidechain-root',
                'isSidechain': true,
                'prompt': msgContent,
                if (dataUuid != null) 'uuid': dataUuid,
                if (dataParentUuid != null)
                  'parentUuid': dataParentUuid,
              },
            ],
            [],
          );
        }
      }

      // Tool results - collect them to update existing tool-call states
      final toolResults = <Map<String, dynamic>>[];
      final msgContent = data['message']?['content'];

      if (msgContent is List) {
        for (final c in msgContent) {
          if (c is Map<String, dynamic> && c['type'] == 'tool_result') {
            toolResults.add({
              'toolUseId': c['tool_use_id'],
              'result': c['content'],
              'isError': c['is_error'] == true,
              'createdAt': createdAt,
              'permissions': c['permissions'],
              if (isSidechain) 'isSidechain': true,
              if (dataUuid != null) 'uuid': dataUuid,
              if (dataParentUuid != null)
                'parentUuid': dataParentUuid,
            });
          }
        }
      }
      return ([], toolResults);
    }

    // Skip system, result, summary messages
    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processEventContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip ready events
    if (data['type'] == 'ready') return ([], []);

    return (
      [
        {
          'id': message.id,
          'localId': message.localId,
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'agent-event',
          'event': data,
          'content': '',
          'raw': outerContent,
        },
      ],
      [],
    );
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processCodexContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final dataType = data['type'] as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': data['input'],
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
          },
        ],
      );
    }

    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processAcpContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final dataType = data['type'] as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (dataType == 'thinking') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${data['text']}*',
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': data['input'],
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-result' || dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
          },
        ],
      );
    }

    if (dataType == 'file-edit') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'file-edit',
            'input': {
              'filePath': data['filePath'],
              'description': data['description'],
              'diff': data['diff'],
              'oldContent': data['oldContent'],
              'newContent': data['newContent'],
            },
            'toolUseId': data['id'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    // Skip task lifecycle events (task_started, task_complete, turn_aborted,
    // token_count, permission-request, etc.)
    return ([], []);
  }

  /// Group sidechain messages as children of their parent Task
  /// tool-call messages and remove them from the main message list.
  void _groupSidechainMessages(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    // Pass 1: Find Task tool calls → map prompt to task message ID
    final promptToTaskId = <String, String>{};
    for (final msg in messages) {
      if (msg['kind'] == 'tool-call' && msg['name'] == 'Task') {
        final input = msg['input'] as Map<String, dynamic>?;
        final prompt = input?['prompt'] as String?;
        if (prompt != null) {
          promptToTaskId[prompt] = msg['id'] as String;
        }
      }
    }
    if (promptToTaskId.isEmpty) return;

    // Pass 2: Combined pass to find sidechain roots and group
    // child messages in a single iteration
    final uuidToSidechainId = <String, String>{};
    final sidechainChildren =
        <String, List<Map<String, dynamic>>>{};
    final sidechainMsgIds = <String>{};

    for (final msg in messages) {
      if (msg['kind'] == 'sidechain-root') {
        final prompt = msg['prompt'] as String?;
        final uuid = msg['uuid'] as String?;
        if (prompt != null && promptToTaskId.containsKey(prompt)) {
          final sidechainId = promptToTaskId[prompt]!;
          if (uuid != null) {
            uuidToSidechainId[uuid] = sidechainId;
          }
          sidechainMsgIds.add(msg['id'] as String);
        }
      } else if (msg['isSidechain'] == true) {
        final uuid = msg['uuid'] as String?;
        final parentUuid = msg['parentUuid'] as String?;

        if (parentUuid != null &&
            uuidToSidechainId.containsKey(parentUuid)) {
          final sidechainId = uuidToSidechainId[parentUuid]!;
          if (uuid != null) {
            uuidToSidechainId[uuid] = sidechainId;
          }
          sidechainChildren
              .putIfAbsent(sidechainId, () => [])
              .add(msg);
          sidechainMsgIds.add(msg['id'] as String);
        }
      }
    }

    if (sidechainMsgIds.isEmpty) return;

    // Pass 3: Remove sidechain messages from main list, attach
    // children to Task tool-call messages (mutate in-place to
    // avoid spread copy overhead)
    final filtered = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final msgId = msg['id'] as String;
      if (sidechainMsgIds.contains(msgId)) continue;

      if (sidechainChildren.containsKey(msgId)) {
        msg['children'] = sidechainChildren[msgId];
      }
      filtered.add(msg);
    }

    _sessionMessages[sessionId] = filtered;
    _sessionMessagesCache = null;

    // Pass 4: Recursively group nested Task children.
    // After pass 3, inner Task tool-calls appear in their
    // parent Task's children array but their own sidechain
    // children are also flattened there. Re-group them so
    // each nested Task gets its own children array.
    for (final msg in filtered) {
      final children =
          msg['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        _regroupNestedTasks(
          children.cast<Map<String, dynamic>>(),
        );
      }
    }
  }

  /// Recursively regroup sidechain children so nested
  /// Task tool-calls within a children array get their
  /// own children sub-arrays.
  void _regroupNestedTasks(
    List<Map<String, dynamic>> children,
  ) {
    // Find inner Task tool-calls and their prompts.
    final promptToTask = <String, Map<String, dynamic>>{};
    for (final child in children) {
      if (child['kind'] == 'tool-call' &&
          child['name'] == 'Task') {
        final input =
            child['input'] as Map<String, dynamic>?;
        final prompt = input?['prompt'] as String?;
        if (prompt != null) {
          promptToTask[prompt] = child;
        }
      }
    }
    if (promptToTask.isEmpty) return;

    // Find sidechain-root messages matching inner Tasks.
    final uuidToTask = <String, Map<String, dynamic>>{};
    final toRemove = <int>{};

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child['kind'] == 'sidechain-root') {
        final prompt = child['prompt'] as String?;
        final uuid = child['uuid'] as String?;
        if (prompt != null &&
            promptToTask.containsKey(prompt) &&
            uuid != null) {
          uuidToTask[uuid] = promptToTask[prompt]!;
          toRemove.add(i);
        }
      }
    }

    if (uuidToTask.isEmpty) return;

    // Group sidechain children under their inner Tasks.
    final taskChildren =
        <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < children.length; i++) {
      if (toRemove.contains(i)) continue;
      final child = children[i];
      if (child['isSidechain'] == true) {
        final parentUuid =
            child['parentUuid'] as String?;
        final uuid = child['uuid'] as String?;
        if (parentUuid != null &&
            uuidToTask.containsKey(parentUuid)) {
          final task = uuidToTask[parentUuid]!;
          final taskId = task['id'] as String;
          taskChildren
              .putIfAbsent(taskId, () => [])
              .add(child);
          if (uuid != null) {
            uuidToTask[uuid] = task;
          }
          toRemove.add(i);
        }
      }
    }

    // Attach children to inner Tasks.
    for (final entry in taskChildren.entries) {
      for (final child in children) {
        if (child['id'] == entry.key) {
          child['children'] = entry.value;
          // Recurse for deeper nesting.
          _regroupNestedTasks(entry.value);
          break;
        }
      }
    }

    // Remove regrouped messages (reverse order).
    final indices = toRemove.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final i in indices) {
      children.removeAt(i);
    }
  }

  /// Apply tool results to existing tool-call messages in a session.
  void _applyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    if (toolResults.isEmpty) return;

    final existing =
        _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    if (existing.isEmpty) return;

    // Build a lookup from toolUseId → index (O(n))
    final toolUseIdToIndex = <String, int>{};
    for (var i = 0; i < existing.length; i++) {
      final msg = existing[i];
      if (msg['kind'] == 'tool-call') {
        final id = msg['toolUseId'] as String?;
        if (id != null) toolUseIdToIndex[id] = i;
      }
    }

    var changed = false;
    final updated = List<Map<String, dynamic>>.from(existing);

    for (final result in toolResults) {
      final toolUseId = result['toolUseId'] as String?;
      if (toolUseId == null) continue;
      final idx = toolUseIdToIndex[toolUseId];
      if (idx == null) continue;

      final msg = updated[idx];
      final isError = result['isError'] == true;

      // Propagate completed permission data from tool result if present.
      Map<String, dynamic>? permissionUpdate;
      final perms = result['permissions'];
      if (perms is Map<String, dynamic>) {
        final permResult = perms['result'] as String?;
        final status =
            permResult == 'approved' ? 'approved' : 'denied';
        permissionUpdate = {
          'id': toolUseId,
          'status': status,
          if (perms['date'] != null) 'date': perms['date'],
          if (perms['mode'] != null) 'mode': perms['mode'],
          if (perms['allowedTools'] != null)
            'allowedTools': perms['allowedTools'],
          if (perms['decision'] != null) 'decision': perms['decision'],
        };
      }

      updated[idx] = {
        ...msg,
        'state': isError ? 'error' : 'completed',
        'result': result['result'],
        'completedAt': result['createdAt'],
        if (permissionUpdate != null) 'permission': permissionUpdate,
      };
      changed = true;
    }

    if (changed) {
      _sessionMessages[sessionId] = updated;
      _sessionMessagesCache = null;
    }
  }

  /// Enrich tool-call messages with permission data from [AgentState].
  ///
  /// The server stores pending permissions in [AgentState.requests] and
  /// completed ones in [AgentState.completedRequests], both keyed by the
  /// tool-use ID.  This mirrors Phase 0 of the React Native reducer which
  /// stamps `permission` onto each matching tool-call message so the UI can
  /// render the Allow / Deny buttons.
  void _applyPermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;

    final agentState = session.agentState;
    if (agentState == null) return;

    final requests = agentState.requests;
    final completedRequests = agentState.completedRequests;

    if ((requests == null || requests.isEmpty) &&
        (completedRequests == null || completedRequests.isEmpty)) {
      return;
    }

    final existing = _sessionMessages[sessionId];
    if (existing == null || existing.isEmpty) return;

    // Build a lookup: toolUseId → index in existing list (O(n)).
    final toolUseIdToIndex = <String, int>{};
    for (var i = 0; i < existing.length; i++) {
      final msg = existing[i];
      if (msg['kind'] == 'tool-call') {
        final id = msg['toolUseId'] as String?;
        if (id != null) toolUseIdToIndex[id] = i;
      }
    }

    var changed = false;
    final updated = List<Map<String, dynamic>>.from(existing);

    // Stamp pending permission onto matching tool-call messages.
    if (requests != null) {
      for (final entry in requests.entries) {
        final permId = entry.key;
        final idx = toolUseIdToIndex[permId];
        if (idx == null) continue;

        final msg = updated[idx];
        // Only add if there is no permission data yet (avoid downgrading
        // a completed permission back to pending on re-fetch).
        if (msg['permission'] == null) {
          updated[idx] = {
            ...msg,
            'permission': {'id': permId, 'status': 'pending'},
          };
          changed = true;
        }
      }
    }

    // Stamp completed permission data onto matching tool-call messages.
    if (completedRequests != null) {
      for (final entry in completedRequests.entries) {
        final permId = entry.key;
        final info = entry.value;
        final idx = toolUseIdToIndex[permId];
        if (idx == null) continue;

        final msg = updated[idx];
        final existingPerm =
            msg['permission'] as Map<String, dynamic>?;
        // Skip if already resolved — the tool-result `permissions` field
        // (applied in _applyToolResults) is more authoritative.
        if (existingPerm != null &&
            existingPerm['status'] != 'pending') {
          continue;
        }

        updated[idx] = {
          ...msg,
          'permission': {
            'id': permId,
            'status': info.status,
            if (info.mode != null) 'mode': info.mode,
            if (info.allowedTools != null)
              'allowedTools': info.allowedTools,
            if (info.decision != null) 'decision': info.decision,
            if (info.reason != null) 'reason': info.reason,
          },
        };
        changed = true;
      }
    }

    if (changed) {
      _sessionMessages[sessionId] = updated;
      _sessionMessagesCache = null;
    }
  }

  void _updateSessionUsage(
    String sessionId,
    Map<String, dynamic> usage,
    int timestamp,
  ) {
    final existing = _sessionUsage[sessionId];
    final existingTs = existing?['timestamp'] as int? ?? 0;
    if (timestamp > existingTs) {
      final inputTokens = usage['input_tokens'] as int? ?? 0;
      final cacheCreation =
          usage['cache_creation_input_tokens'] as int? ?? 0;
      final cacheRead = usage['cache_read_input_tokens'] as int? ?? 0;
      final outputTokens = usage['output_tokens'] as int? ?? 0;
      _sessionUsage[sessionId] = {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cacheCreation': cacheCreation,
        'cacheRead': cacheRead,
        'contextSize': cacheCreation + cacheRead + inputTokens,
        'timestamp': timestamp,
      };
    }
  }

  void _upsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    final merged = <String, Map<String, dynamic>>{
      for (final message in existing) message['id'] as String: message,
    };
    // Build a reverse index from localId → assigned id, so incoming server
    // messages replace the matching optimistic placeholder.
    final localIdToId = <String, String>{};
    for (final message in merged.values) {
      final localId = message['localId'] as String?;
      if (localId != null && localId != message['id']) {
        localIdToId[localId] = message['id'] as String;
      }
    }
    for (final message in messages) {
      final messageId = message['id'] as String;
      final localId = message['localId'] as String?;
      // If this is an incoming server message whose localId matches an
      // optimistic placeholder, remove the placeholder first.
      if (localId != null && localId != messageId) {
        merged.remove(localId);
      }
      // Also remove any existing entry that was the optimistic placeholder
      // for this localId (handles the reverse lookup case).
      if (localId != null) {
        final existingId = localIdToId[localId];
        if (existingId != null && existingId != messageId) {
          merged.remove(existingId);
        }
      }
      merged[messageId] = message;
    }

    final sorted = merged.values.toList();

    // Optimize: skip sort if already sorted (common case when
    // appending new messages).
    var needsSort = false;
    for (var i = 1; i < sorted.length; i++) {
      final prevCreated = _asInt(sorted[i - 1]['createdAt']) ?? 0;
      final currCreated = _asInt(sorted[i]['createdAt']) ?? 0;
      if (prevCreated > currCreated) {
        needsSort = true;
        break;
      }
      // Also check seq if createdAt is equal.
      if (prevCreated == currCreated) {
        final prevSeq = sorted[i - 1]['seq'] as int? ?? 0;
        final currSeq = sorted[i]['seq'] as int? ?? 0;
        if (prevSeq > currSeq) {
          needsSort = true;
          break;
        }
      }
    }

    if (needsSort) {
      sorted.sort((a, b) {
        final aCreated = _asInt(a['createdAt']) ?? 0;
        final bCreated = _asInt(b['createdAt']) ?? 0;
        if (aCreated != bCreated) {
          return aCreated.compareTo(bCreated);
        }
        return (a['seq'] as int? ?? 0)
            .compareTo(b['seq'] as int? ?? 0);
      });
    }

    const maxMessages = 3000;
    _sessionMessages[sessionId] = sorted.length > maxMessages
        ? sorted.sublist(sorted.length - maxMessages)
        : sorted;
    _sessionMessagesCache = null;
  }

  /// Suspend the sync engine when the app goes to the background.
  ///
  /// Disconnects the socket so the OS does not keep reporting connection
  /// errors while the app is backgrounded (which previously caused a
  /// reconnect loop that saturated the main thread on resume). Pending
  /// debounce writes are flushed to MMKV so no cursor data is lost.
  void suspend() {
    if (!isInitialized) return;
    if (kDebugMode) debugPrint('[Sync] suspending — disconnecting socket');
    _dataChangeDebounceTimer?.cancel();
    _saveSeqDebounceTimer?.cancel();
    MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    socketIoClient.disconnect();
  }

  /// Resume the sync engine when the app returns to the foreground.
  ///
  /// Reconnects the socket and invalidates all syncs so any server-side
  /// changes that happened while the app was backgrounded are fetched.
  void resume() {
    if (!isInitialized) return;
    if (kDebugMode) debugPrint('[Sync] resuming — reconnecting socket');
    socketIoClient.reconnect();
    _invalidateAllSyncs();
    // Only re-fetch the visible session's messages; all others are lazy.
    if (_visibleSessionId != null) {
      messagesSync[_visibleSessionId]?.invalidate();
    }
  }

  /// Shutdown sync engine and clear volatile state.
  Future<void> shutdown() async {
    socketIoClient
      ..offMessage('update')
      ..offMessage('ephemeral')
      ..disconnect();

    _dataChangeDebounceTimer?.cancel();
    _dataChangeDebounceTimer = null;
    // Flush any pending seq write before shutdown so cursors aren't lost.
    _saveSeqDebounceTimer?.cancel();
    _saveSeqDebounceTimer = null;
    MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));

    // Do NOT close these broadcast controllers — the Sync singleton is reused
    // after logout+login, and closing a final StreamController is permanent.
    // Listeners (screens that subscribe to onDataChanged) would never receive
    // events again, silently breaking all real-time updates.

    for (final sync in messagesSync.values) {
      sync.dispose();
    }
    messagesSync.clear();
    _sessionLastSeq.clear();
    MMKVStorage().clearSessionLastSeq();
    _sessionFirstLoadedSeq.clear();
    MMKVStorage().clearSessionFirstLoadedSeq();
    _loadingOlderMessages.clear();

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
    sessionGitStatusSync.dispose();

    for (final timer in _presenceTimers.values) {
      timer.cancel();
    }
    _presenceTimers.clear();

    _sessionDataKeys.clear();
    _machineDataKeys.clear();
    _artifactDataKeys.clear();
    _todoLists.clear();
    _friends.clear();
    _friendRequests.clear();
    _feedItems.clear();
    _artifacts.clear();
    _sessionMessages.clear();
    _sessionMessagesCache = null;
    _sessions.clear();
    _lastSessionsFetchedAt = null;
    _machines.clear();
    _sessionGitStatus.clear();
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
    if (kDebugMode) debugPrint('Sync already initialized');
    return;
  }

  final secretKey = Base64Utils.decode(credentials.secret, Encoding.base64url);
  if (secretKey.length != 32) {
    throw StateError(
        'Invalid secret key length: ${secretKey.length}, expected 32');
  }

  final encryption = await Encryption.create(secretKey);
  await sync.create(credentials, encryption);
}

/// Restore sync engine from disk
Future<void> syncRestore(AuthCredentials credentials) async {
  if (sync.isInitialized) {
    if (kDebugMode) debugPrint('Sync already initialized');
    return;
  }

  final secretKey = Base64Utils.decode(credentials.secret, Encoding.base64url);
  if (secretKey.length != 32) {
    throw StateError(
        'Invalid secret key length: ${secretKey.length}, expected 32');
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
