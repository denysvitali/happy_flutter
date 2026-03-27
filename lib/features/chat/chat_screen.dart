import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show Breadcrumb, Hint, ISentrySpan, Sentry, SentryLevel;

import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/session.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/message_cache_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/offline_banner.dart';
import '../sessions/widgets/session_cards.dart'
    show parseAvatarStyle;
import 'chat_input.dart';
import 'message_widget.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_loading_shimmer.dart';
import 'widgets/empty_chat_view.dart';
import 'widgets/permission_mode_selector.dart';
import 'widgets/scroll_to_bottom_pill.dart';

/// Chat screen for a session
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<void>? _dataSyncSubscription;
  StreamSubscription<String>? _messageSyncSubscription;
  bool _isSending = false;
  bool _isAborting = false;
  bool _isLoadingMessages = true;
  bool _loadFailed = false;

  bool _didStartInitialLoad = false;
  Timer? _loadingSafetyTimer;
  int _lastDataChangeCounter = -1;
  int _prevMessagesLength = 0;
  int _prevSeenLength = 0;
  late final ValueNotifier<bool> _autoScrollNotifier =
      ValueNotifier<bool>(true);
  bool get _autoScroll => _autoScrollNotifier.value;
  set _autoScroll(bool value) => _autoScrollNotifier.value = value;
  static const double _autoScrollThreshold = 100;

  PermissionMode _permissionMode = PermissionMode.defaultMode;
  ClaudeModel _modelMode = ClaudeModel.defaultModel;
  /// Raw model mode string from storage, used for non-Claude profiles.
  /// For Claude profiles, this matches _modelMode.modeString.
  /// For other profiles (GLM, MiniMax, etc.), this contains the actual
  /// model string (e.g., 'GLM-5', 'MiniMax-Text-01') while _modelMode
  /// remains ClaudeModel.defaultModel for UI purposes.
  String? _rawModelModeString;
  AIBackendProfile? _selectedProfile;
  List<AIBackendProfile> _availableProfiles = const [];
  Session? _session;
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _metadataJson;
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  int _lastLoadMoreMs = 0;

  // Cached slicing / index data for _buildMessageList.
  List<Map<String, dynamic>>? _cachedVisibleMessages;
  List<Map<String, dynamic>>? _cachedVisibleSource;
  int _cachedMessagesLength = -1;
  int _cachedVisibleCount = -1;

  bool _initialLoadComplete = false;
  final Set<String> _seenMessageIds = {};

  // Track when the actual messages list changes (not just rebuilds)
  List<Map<String, dynamic>>? _lastMessagesList;

  // Pre-computed neighbor cache for message list items (replacing O(N) scans).
  final Map<int, (Map<String, dynamic>?, Map<String, dynamic>?)>
      _neighborCache = {};
  List<Map<String, dynamic>?>? _neighborCacheSource;
  int _neighborCacheLength = -1;
  int _neighborCacheSourceHash = 0;

  void _rebuildNeighborCache(List<Map<String, dynamic>?> items) {
    // Fast-path: check if we can skip the rebuild entirely
    if (identical(items, _neighborCacheSource) &&
        items.length == _neighborCacheLength) {
      return;
    }

    // Compute a lightweight hash to detect content changes without O(N) scan
    // We combine length + first/last item identity for a cheap but effective check
    final newHash = items.length ^
        (items.isNotEmpty ? items.first.hashCode : 0) ^
        (items.isNotEmpty ? items.last.hashCode : 0);

    if (items.length == _neighborCacheLength &&
        newHash == _neighborCacheSourceHash &&
        identical(items, _neighborCacheSource)) {
      return;
    }

    _neighborCacheSource = items;
    _neighborCacheLength = items.length;
    _neighborCacheSourceHash = newHash;
    _neighborCache.clear();

    // Collect non-null indices once - O(N)
    final nonNullIndices = <int>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i] != null) nonNullIndices.add(i);
    }

    // For each non-null index, find prev/next from the nonNullIndices list - O(N)
    for (var k = 0; k < nonNullIndices.length; k++) {
      final i = nonNullIndices[k];
      final prev = k > 0 ? items[nonNullIndices[k - 1]] : null;
      final next = k < nonNullIndices.length - 1
          ? items[nonNullIndices[k + 1]]
          : null;
      _neighborCache[i] = (prev, next);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialSettings();

    // ── Local-first: Load cached messages instantly (0ms delay) ──
    final cached = MessageCacheService().getMessages(widget.sessionId);
    if (cached.isNotEmpty) {
      setState(() {
        _messages = cached;
        _isLoadingMessages = false;
        // Mark cached messages as seen so they don't animate
        for (final m in cached) {
          _seenMessageIds.add(_messageKey(m));
        }
        _prevSeenLength = cached.length;
        _visibleCount = cached.length;
      });
      logger.info(
        '[ChatScreen] Loaded ${cached.length} cached messages for '
        'session ${widget.sessionId} '
        'visibleCount=$_visibleCount',
      );
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'ChatScreen: initState cache hit',
        category: 'chat.load',
        data: {
          'sessionId': widget.sessionId,
          'cachedCount': cached.length,
          'visibleCount': _visibleCount,
        },
      ));
    }

    _initializeSyncBackedChat();
    final settings = ref.read(settingsNotifierProvider);
    if (settings.ttsEnabled) {
      unawaited(
        TtsService().init(
          language: settings.voiceAssistantLanguage,
          engine: settings.ttsEngine,
        ),
      );
    }
  }


  /// Batches three async storage reads into a single setState call
  /// to avoid 3 separate rebuilds on screen open.
  Future<void> _loadInitialSettings() async {
    final storage = DraftStorage();
    final sessionId = widget.sessionId;

    // Fire all three reads in parallel.
    final results = await Future.wait([
      storage.getPermissionMode(sessionId),
      storage.getModelMode(sessionId),
      storage.getProfileId(sessionId),
    ]);

    if (!mounted) return;

    final savedPermMode = results[0];
    final savedModelMode = results[1];
    final savedProfileId = results[2];

    final session = sync.sessions[sessionId];

    // Permission mode.
    var permissionMode = PermissionMode.defaultMode;
    if (savedPermMode != null) {
      permissionMode =
          PermissionModeExtension.fromString(savedPermMode) ??
          PermissionMode.defaultMode;
    } else if (session?.permissionMode != null) {
      permissionMode =
          PermissionModeExtension.fromString(session!.permissionMode!) ??
          PermissionMode.defaultMode;
      unawaited(
        storage.savePermissionMode(
          sessionId,
          permissionMode.toModeString(),
        ),
      );
    }

    // Profile & settings (read once, used below for both model and profile).
    final settings = ref.read(settingsNotifierProvider);

    // First, determine the selected profile so we can use its defaultModelMode.
    // Profile.
    final seen = <String>{};
    final deduped = <AIBackendProfile>[];
    for (final p in [...settings.profiles, ...builtInProfiles]) {
      if (seen.add(p.id)) deduped.add(p);
    }

    AIBackendProfile? selectedProfile;
    final effectiveProfileId = savedProfileId ?? settings.lastUsedProfile;
    if (effectiveProfileId != null) {
      try {
        selectedProfile =
            deduped.firstWhere((p) => p.id == effectiveProfileId);
      } catch (_) {
        selectedProfile = null;
      }
    }

    // Model mode.
    final flavor = session?.metadata?.flavor;
    String? rawModelModeString;
    var modelMode = ClaudeModel.defaultModel;

    // Priority: saved draft > session model > profile default > settings default
    if (savedModelMode != null) {
      rawModelModeString = savedModelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(savedModelMode),
        flavor,
      );
    } else if (session?.modelMode != null) {
      rawModelModeString = session!.modelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(session.modelMode),
        flavor,
      );
    } else if (selectedProfile?.defaultModelMode != null) {
      // Use the profile's default model mode
      rawModelModeString = selectedProfile!.defaultModelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(selectedProfile.defaultModelMode),
        flavor,
      );
    } else if (settings.lastUsedModelMode != null) {
      // Fall back to the user's last-used model preference so new sessions
      // inherit the model the user most recently picked.
      rawModelModeString = settings.lastUsedModelMode;
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(settings.lastUsedModelMode),
        flavor,
      );
    }

    setState(() {
      _permissionMode = permissionMode;
      _modelMode = modelMode;
      _rawModelModeString = rawModelModeString;
      _availableProfiles = deduped;
      _selectedProfile = selectedProfile;
    });
  }

  @override
  void dispose() {
    _loadingSafetyTimer?.cancel();
    _dataSyncSubscription?.cancel();
    _messageSyncSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _autoScrollNotifier.dispose();
    TtsService().stop();
    super.dispose();
  }

  Future<void> _initializeSyncBackedChat() async {
    _messageSyncSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) {
          if (mounted) _refreshFromSync();
        });
    _dataSyncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      final counter = sync.dataChangeCounter;
      if (counter == _lastDataChangeCounter) return;
      _lastDataChangeCounter = counter;
      if (!_didStartInitialLoad && sync.isInitialized) {
        _doInitialLoad();
      } else {
        final latest = sync.sessions[widget.sessionId];
        if (latest != _session) {
          _refreshFromSync();
        }
      }
    });

    if (!sync.isInitialized) {
      return;
    }

    await _doInitialLoad();
  }

  Future<void> _doInitialLoad() async {
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;
    final sessionId = widget.sessionId;
    final stopwatch = Stopwatch()..start();
    var success = true;

    // Start a Sentry transaction for the entire chat loading flow
    final transaction = Sentry.startTransaction(
      'chat.screen.load',
      'ui.load',
      bindToScope: true,
    ) as ISentrySpan;
    transaction.setData('sessionId', sessionId);

    // Safety timer: if loading is still in progress after 15s,
    // force-clear the spinner and report to Sentry.
    _loadingSafetyTimer?.cancel();
    _loadingSafetyTimer = Timer(
      const Duration(seconds: 15),
      () {
        if (!mounted || !_isLoadingMessages) return;
        logger.warning(
          '[ChatScreen] Safety timeout: loading stuck '
          'for 15s session=$sessionId '
          'messages=${_messages.length}',
        );
        unawaited(Sentry.captureMessage(
          'ChatScreen loading stuck for 15s',
          level: SentryLevel.warning,
          params: [sessionId],
          hint: Hint.withMap({
            'sessionId': sessionId,
            'messageCount':
                _messages.length.toString(),
            'initialLoadComplete':
                _initialLoadComplete.toString(),
            'syncInitialized':
                sync.isInitialized.toString(),
            'hasMsgSync':
                (sync.messagesSync[sessionId] != null)
                    .toString(),
            'syncMessages': sync
                .messagesForSession(sessionId)
                .length
                .toString(),
            'elapsedMs': stopwatch.elapsedMilliseconds,
          }),
        ));
        // Finish the transaction as failed
        transaction.setData('timeout', true);
        unawaited(transaction.finish());
        setState(() {
          _isLoadingMessages = false;
          _initialLoadComplete = true;
          if (_messages.isEmpty) _loadFailed = true;
        });
      },
    );

    try {
      final cacheSpan = transaction.startChild(
        'chat.cache.check',
        description: 'Check cached messages',
      );
      cacheSpan.setData('cachedCount', _messages.length);
      cacheSpan.finish();

      Sentry.addBreadcrumb(Breadcrumb(
        message: 'ChatScreen._doInitialLoad started',
        category: 'chat.load',
        data: {
          'sessionId': sessionId,
          'hasCachedMessages': _messages.isNotEmpty,
          'syncInitialized': sync.isInitialized,
        },
      ));

      // Span for onSessionVisible
      final visibleSpan = transaction.startChild(
        'chat.sync.visible',
        description: 'Mark session as visible',
      );
      sync.onSessionVisible(sessionId);
      visibleSpan.finish();

      // Show cached messages immediately instead of
      // waiting for the debounced stream notification
      // (100ms). onSessionVisible() loads the MMKV cache
      // synchronously so sync already has messages in
      // memory at this point.
      final refreshSpan = transaction.startChild(
        'chat.sync.refresh',
        description: 'Refresh from sync singleton',
      );
      _refreshFromSync();
      refreshSpan.finish();

      // Span for awaiting message sync queue
      final awaitSpan = transaction.startChild(
        'chat.sync.await',
        description: 'Await message sync queue',
      );
      try {
        await sync.messagesSync[sessionId]
            ?.awaitQueue()
            .timeout(const Duration(seconds: 5));
        awaitSpan.setData('timedOut', false);
      } catch (e) {
        success = false;
        awaitSpan.setData('timedOut', true);
        awaitSpan.setData('error', e.toString());
      }
      awaitSpan.finish();
    } catch (error, stack) {
      success = false;
      logger.error(
        '[ChatScreen] _doInitialLoad error '
        'session=$sessionId',
        error,
        stack,
      );
      transaction.setData('error', error.toString());
      unawaited(Sentry.captureException(
        error,
        stackTrace: stack,
        hint: Hint.withMap({
          'context': 'ChatScreen._doInitialLoad',
          'sessionId': sessionId,
        }),
      ));
    } finally {
      _loadingSafetyTimer?.cancel();
      _loadingSafetyTimer = null;
    }

    if (!mounted) {
      await transaction.finish();
      return;
    }

    Sentry.addBreadcrumb(Breadcrumb(
      message: 'ChatScreen._doInitialLoad completed',
      category: 'chat.load',
      data: {
        'sessionId': sessionId,
        'success': success,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'messageCount': _messages.length,
        'syncMessages':
            sync.messagesForSession(sessionId).length,
      },
    ));

    _refreshFromSync(
      markLoaded: true,
      loadFailed: !success && _messages.isEmpty,
    );

    // Finish the transaction
    transaction.setData('finalMessageCount', _messages.length);
    transaction.setData('elapsedMs', stopwatch.elapsedMilliseconds);
    await transaction.finish();
  }

  Future<void> _retry() async {
    if (!mounted) return;
    _loadingSafetyTimer?.cancel();
    setState(() {
      _loadFailed = false;
      _isLoadingMessages = true;
      _didStartInitialLoad = false;
    });
    await _doInitialLoad();
  }

  void _refreshFromSync({bool markLoaded = false, bool loadFailed = false}) {
    final latestSession = sync.sessions[widget.sessionId];
    final latestMessages = sync.messagesForSession(widget.sessionId);

    final sessionChanged = latestSession != _session;
    var messagesChanged = !identical(latestMessages, _messages);

    // When the session changes, always refresh messages — the session
    // object replacement may coincide with message updates that the
    // identical() check can miss (e.g. view cache was rebuilt between
    // calls with the same list length but different content).
    if (sessionChanged && !messagesChanged) {
      messagesChanged = true;
    }

    // Never silently drop a state where the Sync singleton has messages
    // but our local list is empty. This catches edge cases where the
    // view cache was cleared (e.g. gapTooLarge tail refresh) and the
    // UI got updated with an empty list before the HTTP fetch completed.
    if (!messagesChanged &&
        latestMessages.isNotEmpty &&
        _messages.isEmpty) {
      messagesChanged = true;
    }

    logger.info(
      '[ChatScreen] _refreshFromSync '
      'session=${widget.sessionId} '
      'markLoaded=$markLoaded '
      'loadFailed=$loadFailed '
      'sessionChanged=$sessionChanged '
      'messagesChanged=$messagesChanged '
      'latestMsgs=${latestMessages.length} '
      'currentMsgs=${_messages.length} '
      'visibleCount=$_visibleCount',
    );

    if (!sessionChanged && !messagesChanged && !markLoaded && !loadFailed) {
      return;
    }

    if (!mounted) return;

    // Invalidate neighbor cache when messages actually change
    if (messagesChanged && !identical(latestMessages, _lastMessagesList)) {
      _invalidateNeighborCache();
      _lastMessagesList = latestMessages;
    }

    final hadRequests = _session?.agentState?.requests?.isNotEmpty ?? false;
    final hasRequests =
        latestSession?.agentState?.requests?.isNotEmpty ?? false;
    final newPermission = !hadRequests && hasRequests;

    // Batch all state updates into a single setState
    setState(() {
      // Update session and metadata
      if (sessionChanged) {
        _session = latestSession;
        _metadataJson = latestSession?.metadata?.toJson();
      }

      // Update model mode
      _modelMode = ClaudeModel.normalizeForFlavor(
        _modelMode,
        latestSession?.metadata?.flavor,
      );

      // Handle markLoaded unconditionally — the HTTP fetch completed even if
      // no messages changed (e.g. empty session or subagent session).
      if (markLoaded) {
        _isLoadingMessages = false;
        _initialLoadComplete = true;
        // Always sync _prevMessagesLength so the next messagesChanged
        // adjustment is correct (prevMessagesLength is only set inside the
        // messagesChanged block below, so it must be set here too).
        _prevMessagesLength = latestMessages.length;
        // When _prevMessagesLength was 0 (cold start), the messagesChanged
        // adjustment above could not run (_prevMessagesLength > 0 guard failed).
        // Sync _visibleCount here so all loaded messages are visible immediately.
        if (_visibleCount < latestMessages.length) {
          _visibleCount = latestMessages.length;
        }
      }

      // Update messages and visible count
      if (messagesChanged) {
        if (latestMessages.length > _prevMessagesLength) {
          final prepended = latestMessages.length - _prevMessagesLength;
          if (_visibleCount >= _prevMessagesLength && _prevMessagesLength > 0) {
            _visibleCount = (_visibleCount + prepended).clamp(
              0,
              latestMessages.length,
            );
          }
        }

        _messages = latestMessages;
        _prevMessagesLength = latestMessages.length;

        // Handle message visibility and seen tracking
        if (markLoaded) {
          _markMessagesAsSeen(latestMessages, 0, latestMessages.length);
        } else if (latestMessages.isNotEmpty) {
          // Cached messages arrived from MMKV (via onSessionVisible) — dismiss
          // the shimmer immediately instead of waiting for the HTTP round-trip.
          _isLoadingMessages = false;
          if (!_initialLoadComplete) {
            // First time we see messages (from cache) — mark them as seen so
            // they don't animate. Only genuinely new messages should animate.
            _markMessagesAsSeen(latestMessages, 0, latestMessages.length);
          } else {
            // Mark only new messages as seen
            final oldLen = _prevSeenLength;
            final newLen = latestMessages.length;
            if (newLen > oldLen) {
              _markMessagesAsSeen(latestMessages, oldLen, newLen);
            }
          }
          _prevSeenLength = latestMessages.length;
        }
      } else if (_initialLoadComplete && latestMessages.isNotEmpty) {
        // Only mark new messages as seen when list didn't change reference
        final oldLen = _prevSeenLength;
        final newLen = latestMessages.length;
        if (newLen > oldLen) {
          _markMessagesAsSeen(latestMessages, oldLen, newLen);
          _prevSeenLength = newLen;
        }
      }

      // Update load failed state
      if (loadFailed) {
        _loadFailed = true;
      }
    });

    // Post-state-update side effects
    if (messagesChanged && _autoScroll) {
      _scrollToBottom();
    }

    if (newPermission) {
      _scrollToBottom();
    }

    if (messagesChanged && latestMessages.isNotEmpty) {
      final last = latestMessages.last;
      final role = last['role'] as String? ?? '';
      final kind = last['kind'] as String?;
      if (role == 'assistant' && kind != 'tool-call') {
        final ttsOn = ref.read(settingsNotifierProvider).ttsEnabled;
        if (ttsOn) {
          final text = (last['content'] ?? last['text'] ?? '').toString();
          if (text.isNotEmpty) {
            unawaited(TtsService().speak(text));
          }
        }
      }
    }
  }

  /// Marks messages in the range [start, end) as seen to prevent animations.
  void _markMessagesAsSeen(
    List<Map<String, dynamic>> messages,
    int start,
    int end,
  ) {
    for (var i = start; i < end; i++) {
      _seenMessageIds.add(_messageKey(messages[i]));
    }
  }

  /// Invalidates the neighbor cache. Call this when the messages list changes.
  void _invalidateNeighborCache() {
    _neighborCache.clear();
    _neighborCacheSource = null;
    _neighborCacheLength = -1;
    _neighborCacheSourceHash = 0;
  }

  String _messageKey(Map<String, dynamic> m) =>
      m['id'] as String? ?? m['toolUseId'] as String? ?? '';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: AppDuration.fast,
        curve: AppCurve.enter,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    final nearBottom = pos.pixels <= _autoScrollThreshold;
    if (nearBottom != _autoScroll) {
      // Updating the ValueNotifier directly — no setState needed,
      // only the pill's ValueListenableBuilder will rebuild.
      _autoScroll = nearBottom;
    }

    // In a reverse ListView (reverse: true), index 0 (oldest message) is at
    // the BOTTOM and the last index (newest message) is at the TOP.
    // At pixels = 0 (minScrollExtent): at the TOP, viewing newest messages.
    // At pixels = maxScrollExtent: at the BOTTOM, viewing oldest messages.
    //
    // Older messages are at the BOTTOM (index 0 direction), so we load older
    // messages when the user scrolls to the BOTTOM — near maxScrollExtent.
    final atBottom = pos.pixels >= pos.maxScrollExtent - 300;
    if (atBottom) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastLoadMoreMs >= 200) {
        _lastLoadMoreMs = now;
        _loadMore();
      }
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;

    if (_visibleCount < _messages.length) {
      _isLoadingMore = true;
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(0, _messages.length);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isLoadingMore = false;
      });
      return;
    }

    if (sync.hasOlderMessages(widget.sessionId) &&
        !sync.isLoadingOlderMessages(widget.sessionId)) {
      sync.fetchOlderMessages(widget.sessionId);
    }
  }

  String _getSessionTitle() {
    final summary = _session?.metadata?.summary?.text;
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }
    final path = _session?.metadata?.path;
    if (path != null && path.isNotEmpty) {
      return path.split('/').last;
    }
    return 'Chat';
  }

  String _getStatusText(BuildContext context) {
    final session = _session;
    if (session == null) return '';
    final l10n = context.l10n;

    final hasRequests = session.agentState?.requests?.isNotEmpty ?? false;
    if (hasRequests) return l10n.chatPermissionRequired;

    if (session.thinking) return l10n.chatThinking;

    if (session.presence == 'online') {
      return l10n.chatOnline;
    }

    final lastSeen = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return l10n.chatLastSeenJustNow;
    if (diff.inMinutes < 60) {
      return l10n.chatLastSeenMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.chatLastSeenHours(diff.inHours);
    }
    return l10n.chatLastSeenDays(diff.inDays);
  }

  Color _getStatusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = _session;
    if (session == null) return colorScheme.outline;

    if (session.agentState?.requests?.isNotEmpty ?? false) {
      return AppColors.info;
    }
    if (session.thinking) return colorScheme.primary;
    if (session.presence == 'online') {
      return AppColors.success;
    }
    return colorScheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final isThinking = _session?.thinking ?? false;
    final availableModels = ClaudeModel.availableForProfile(
      flavor: _session?.metadata?.flavor,
      claudeCompatible: _selectedProfile?.compatibility.claude ?? true,
    );

    // Use select() so this build only re-runs when the specific settings
    // fields actually change, not on any settings mutation.
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select(
        (s) => parseAvatarStyle(s.avatarStyle),
      ),
    );
    final enterToSend = ref.watch(
      settingsNotifierProvider.select((s) => s.agentInputEnterToSend),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final hasUnsentMessage = value.text.trim().isNotEmpty;
        return PopScope(
          canPop: !hasUnsentMessage,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && hasUnsentMessage) {
              _showUnsentMessageDialog(context);
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: ChatAppBar(
          session: _session,
          sessionTitle: _getSessionTitle(),
          statusText: _getStatusText(context),
          statusColor: _getStatusColor(context),
          isThinking: isThinking,
          sessionId: widget.sessionId,
          avatarStyle: avatarStyle,
          modelLabel: _modelMode == ClaudeModel.defaultModel
              ? null
              : _modelMode.label,
          onInfoTap: () {
            HapticFeedback.lightImpact();
            context.pushNamed(
              'session-info',
              pathParameters: {
                'sessionId': widget.sessionId,
              },
            );
          },
          onMenuTap: () => _showSessionMenu(context),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: AppDuration.normal,
                    child: _isLoadingMessages
                        ? const ChatLoadingShimmer(key: ValueKey('loading'))
                        : _messages.isEmpty
                        ? (_loadFailed
                              ? _buildRetryView()
                              : EmptyChatView(
                                  key: const ValueKey('empty'),
                                  onSuggestionTap: _onSuggestionTap,
                                ))
                        : _buildMessageList(),
                  ),
                  // The scroll-to-bottom pill listens to _autoScrollNotifier
                  // directly so that scroll events do NOT trigger a full
                  // _ChatScreenState rebuild (message list + app bar).
                  RepaintBoundary(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _autoScrollNotifier,
                      builder: (context, autoScroll, _) {
                        return ExcludeSemantics(
                          excluding: autoScroll || _isLoadingMessages,
                          child: IgnorePointer(
                            ignoring: autoScroll || _isLoadingMessages,
                            child: AnimatedOpacity(
                              opacity: (!autoScroll && !_isLoadingMessages)
                                  ? 1.0
                                  : 0.0,
                              duration: AppDuration.normal,
                              curve: AppCurve.standard,
                              child: AnimatedScale(
                                scale: (!autoScroll && !_isLoadingMessages)
                                    ? 1.0
                                    : 0.8,
                                duration: AppDuration.normal,
                                curve: AppCurve.standard,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child: ScrollToBottomPill(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _autoScroll = true;
                                        _scrollToBottom();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            ChatInput(
              sessionId: widget.sessionId,
              controller: _controller,
              onSend: _sendMessage,
              isSending: _isSending,
              permissionMode: _permissionMode,
              onPermissionModeChanged: _onPermissionModeChanged,
              modelMode: _modelMode,
              availableModels: availableModels,
              onModelModeChanged: _onModelModeChanged,
              selectedProfile: _selectedProfile,
              availableProfiles: _availableProfiles,
              onProfileChanged: _onProfileChanged,
              contextSize:
                  sync.sessionUsage[widget.sessionId]?['contextSize'] as int?,
              isSessionOnline: _session?.isPresenceOnline ?? false,
              isAgentThinking: _session?.thinking ?? false,
              enterToSend: enterToSend,
            ),
          ],
        ),
      ),
    );
  }

  void _onPermissionModeChanged(PermissionMode mode) {
    setState(() => _permissionMode = mode);
    ref
        .read(chatActionNotifierProvider.notifier)
        .savePermissionMode(widget.sessionId, mode.toModeString());
  }

  void _onModelModeChanged(ClaudeModel model) {
    final normalized = ClaudeModel.normalizeForFlavor(
      model,
      _session?.metadata?.flavor,
    );
    setState(() {
      _modelMode = normalized;
      _rawModelModeString = normalized.modeString;
    });
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveModelMode(widget.sessionId, normalized.modeString);
  }

  void _onProfileChanged(AIBackendProfile? profile) {
    // Use the profile's default model mode when switching providers.
    // If no profile is selected, fall back to ClaudeModel.defaultModel.
    final profileDefaultModelMode = profile?.defaultModelMode;
    final newModel = profileDefaultModelMode != null
        ? ClaudeModel.normalizeForFlavor(
            ClaudeModel.fromString(profileDefaultModelMode),
            _session?.metadata?.flavor,
          )
        : ClaudeModel.defaultModel;
    final rawModelString = profileDefaultModelMode ?? newModel.modeString;
    setState(() {
      _selectedProfile = profile;
      _modelMode = newModel;
      _rawModelModeString = rawModelString;
    });
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveProfile(widget.sessionId, profile?.id);
    // Save the profile's defaultModelMode, not 'default'
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveModelMode(
          widget.sessionId,
          rawModelString,
        );

    // If the session is currently running, show a warning that the
    // profile change will only take effect after the session is restarted.
    final isRunning = _session?.isPresenceOnline ?? false;
    if (isRunning && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile changed. Restart the session to apply new environment variables.',
          ),
          action: SnackBarAction(
            label: 'Restart',
            textColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () async {
              try {
                await sync.killSession(widget.sessionId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session restarted. Send a message to resume.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                // Trigger a refresh to update the session state
                _refreshFromSync();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to restart session: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  static const _abortReason =
      "The user doesn't want to proceed with this tool "
      'use. The tool use was rejected (eg. if it was a '
      'file edit, the new_string was NOT written to the '
      'file). STOP what you are doing and wait for the '
      'user to tell you how to proceed.';

  Future<void> _abortSession() async {
    if (_isAborting) return;
    setState(() => _isAborting = true);
    try {
      await ref
          .read(chatActionNotifierProvider.notifier)
          .abortSession(widget.sessionId, reason: _abortReason);
    } finally {
      if (mounted) setState(() => _isAborting = false);
    }
  }

  void _showSessionMenu(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      backgroundColor: cs.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: cs.onSurfaceVariant,
              ),
              title: Text(l10n.chatSessionSettings),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                context.pushNamed(
                  'session-info',
                  pathParameters: {'sessionId': widget.sessionId},
                );
              },
            ),
            if (_session?.thinking ?? false)
              ListTile(
                leading: Icon(Icons.stop_rounded, color: cs.error),
                title: Text(
                  'Stop',
                  style: TextStyle(color: cs.error),
                ),
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context);
                  _abortSession();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: cs.error),
              title: Text(
                l10n.chatDeleteSession,
                style: TextStyle(color: cs.error),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryView() {
    return Center(
      key: const ValueKey('retry'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.chatFailedToLoadMessages,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: _retry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final totalCount = _messages.length;
    final startIndex = (totalCount - _visibleCount).clamp(0, totalCount);

    if (!identical(_messages, _cachedVisibleSource) ||
        totalCount != _cachedMessagesLength ||
        _visibleCount != _cachedVisibleCount) {
      _cachedVisibleSource = _messages;
      _cachedMessagesLength = totalCount;
      _cachedVisibleCount = _visibleCount;
      _cachedVisibleMessages = _messages.sublist(startIndex);
    }
    final visibleMessages = _cachedVisibleMessages!;

    final hasLocalMore = startIndex > 0;

    final allLocalVisible = _visibleCount >= totalCount;
    final isLoadingFromServer =
        allLocalVisible && sync.isLoadingOlderMessages(widget.sessionId);
    final hasServerMore =
        allLocalVisible && sync.hasOlderMessages(widget.sessionId);

    final showHeader =
        hasLocalMore ||
        isLoadingFromServer ||
        (!hasServerMore && allLocalVisible && totalCount > 0);

    final metadataJson = _metadataJson;

    final items = <Map<String, dynamic>?>[];
    for (final msg in visibleMessages) {
      // Sidechain (agent) messages should only appear inside
      // the AgentConversationScreen, never in the main chat.
      if (msg['isSidechain'] == true) continue;
      items.add(msg);
      final role = msg['role'] as String?;
      final content = msg['content'] ?? msg['text'];
      final text = content is String ? content : content?.toString() ?? '';
      if (role == 'user' && text.trim() == '/clear') {
        items.add(null);
      }
    }

    final keyToListIndex = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      if (m == null) continue;
      final k = m['id'] as String? ?? m['toolUseId'] as String?;
      if (k != null) {
        keyToListIndex[k] = items.length - 1 - i;
      }
    }

    // Only rebuild neighbor cache if the items list actually changed
    // The _refreshFromSync method handles cache invalidation when messages
    // change.
    _rebuildNeighborCache(items);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.only(
        top: AppSpacing.xsm,
        bottom: AppSpacing.xs,
      ),
      itemCount: items.length + (showHeader ? 1 : 0),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        return keyToListIndex[key.value];
      },
      itemBuilder: (context, index) {
        final adjusted = index;
        if (showHeader && adjusted == items.length) {
          if (hasLocalMore || isLoadingFromServer) {
            return Center(
              key: ValueKey(
                hasLocalMore ? 'header-local-more' : 'header-server-loading',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(
                      alpha: AppOpacity.medium,
                    ),
                  ),
                ),
              ),
            );
          }

          return _buildConversationStartLabel(context);
        }

        final reversedIndex = items.length - 1 - adjusted;
        final item = items[reversedIndex];

        if (item == null) {
          return _buildClearedDivider(context);
        }

        final message = item;
        final (prevMessage, nextMessage) =
            _neighborCache[reversedIndex] ?? (null, null);

        final currentRole = message['role'] as String?;
        final nextRole = nextMessage?['role'] as String?;
        final sameSender = nextRole == currentRole;
        final isToolCall = message['kind'] == 'tool-call';
        final nextIsToolCall = nextMessage?['kind'] == 'tool-call';
        final bottomPad = (isToolCall && nextIsToolCall)
            ? 0.0
            : sameSender
            ? AppSpacing.xs
            : AppSpacing.md;

        final prevRole = prevMessage?['role'] as String?;
        final isFirstInGroup = nextRole != currentRole;
        final isLastInGroup = prevRole != currentRole;

        final messageKey =
            message['id'] as String? ??
            message['toolUseId'] as String? ??
            'msg-$reversedIndex';
        // Only pass the full messages list to tool-call items that need it
        // (Task / Agent sub-conversation rendering). Regular text messages
        // don't use it and passing _messages to every item causes every
        // MessageWidget to see a changed prop on each new message arrival.
        final toolName = isToolCall ? message['name'] as String? : null;
        final needsMessages =
            isToolCall &&
            (toolName == 'Task' || toolName == 'Agent');
        return RepaintBoundary(
          key: ValueKey(messageKey),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: MessageWidget(
              messageData: message,
              isFromCurrentUser: message['role'] == 'user',
              metadata: metadataJson,
              messages: needsMessages ? _messages : null,
              sessionId: widget.sessionId,
              isSessionOnline:
                  (_session?.isOnline ?? false) ||
                  ((_session?.metadata?.machineId?.isNotEmpty ?? false) &&
                      (_session?.metadata?.path?.isNotEmpty ?? false)),
              onOptionPress: _onOptionPress,
              onRetry: message['role'] == 'user' &&
                      message['sendStatus'] == 'failed'
                  ? () => _retryMessage(message)
                  : null,
              animate:
                  _initialLoadComplete && !_seenMessageIds.contains(messageKey),
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationStartLabel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('header-beginning'),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.xxl,
      ),
      child: Center(
        child: Text(
          context.l10n.chatBeginningOfConversation,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(
              alpha: AppOpacity.half,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearedDivider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = cs.onSurfaceVariant.withValues(
      alpha: AppOpacity.half,
    );
    return Padding(
      key: const ValueKey('cleared-divider'),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: AppBorder.thin,
              color: labelColor.withValues(
                alpha: AppOpacity.medium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: Text(
              context.l10n.chatConversationCleared,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontSize: AppFontSize.xxs,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: AppBorder.thin,
              color: labelColor.withValues(
                alpha: AppOpacity.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
  }

  Future<void> _onOptionPress(String option) async {
    if (_isSending) return;
    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            option,
            displayText: option,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _rawModelModeString ?? _modelMode.modeString,
          );
      if (_followRedirectedSession(sentSessionId)) {
        return;
      }
      _refreshFromSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.chatFailedToSend}: $e')),
        );
      }
    }
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    final localId = message['localId'] as String? ?? message['id'] as String?;
    if (localId == null) return;

    try {
      await sync.retryFailedMessage(widget.sessionId, localId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retry message: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    unawaited(TtsService().stop());

    if (text == '/clear') {
      _controller.clear();
      unawaited(DraftStorage().removeDraft(widget.sessionId));
      _autoScrollNotifier.value = true;
      setState(() {
        _isSending = true;
        _visibleCount = _pageSize;
      });
      try {
        final sentSessionId = await ref
            .read(chatActionNotifierProvider.notifier)
            .sendMessage(
              widget.sessionId,
              text,
              permissionMode: _permissionMode.toModeString(),
              modelMode: _rawModelModeString ?? _modelMode.modeString,
            );
        if (_followRedirectedSession(sentSessionId)) {
          return;
        }
        _refreshFromSync();
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          setState(() {
            _controller.text = text;
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatFailedToClear(e.toString())),
            ),
          );
        }
      } finally {
        if (mounted && _isSending) {
          setState(() => _isSending = false);
        }
      }
      return;
    }

    _autoScrollNotifier.value = true;

    // ── Optimistic UI: Show message immediately ──
    final optimisticMessage = <String, dynamic>{
      'id': 'optimistic-${DateTime.now().millisecondsSinceEpoch}',
      'role': 'user',
      'content': text,
      'text': text,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'seq': -1, // Will be replaced by server
      'sendStatus': 'sending', // Track for potential rollback
    };
    setState(() {
      _messages = [..._messages, optimisticMessage];
      _isSending = true;
      _controller.clear();
      _visibleCount = (_visibleCount + 1).clamp(0, _messages.length);
      _invalidateNeighborCache();
    });
    _scrollToBottom();

    unawaited(DraftStorage().removeDraft(widget.sessionId));

    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            text,
            displayText: text,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _rawModelModeString ?? _modelMode.modeString,
          );
      if (_followRedirectedSession(sentSessionId)) {
        return;
      }
      // Optimistic message will be replaced by real message via WebSocket
      _refreshFromSync();
    } catch (e) {
      if (mounted) {
        // Rollback: remove optimistic message on error
        setState(() {
          _messages = _messages
              .where((m) => m['id'] != optimisticMessage['id'])
              .toList();
          _controller.text = text;
          _isSending = false;
          _invalidateNeighborCache();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.chatFailedToSend}: $e')),
        );
      }
    } finally {
      if (mounted && _isSending) {
        setState(() => _isSending = false);
      }
    }
  }

  bool _followRedirectedSession(String sentSessionId) {
    if (!mounted || sentSessionId == widget.sessionId) {
      return false;
    }
    context.goNamed('chat', pathParameters: {'sessionId': sentSessionId});
    return true;
  }

  void _showUnsentMessageDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.chatUnsentMessageTitle),
        content: Text(context.l10n.chatUnsentMessageContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.chatStay),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () {
              _controller.clear();
              unawaited(DraftStorage().removeDraft(widget.sessionId));
              Navigator.pop(context);
              Navigator.of(this.context).pop();
            },
            child: Text(context.l10n.chatLeave),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteSession),
        content: Text(l10n.chatDeleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(context);
              final failedL10n = l10n;
              final deleted = await ref
                  .read(sessionsNotifierProvider.notifier)
                  .optimisticDelete(widget.sessionId);
              if (!mounted) return;
              if (deleted) {
                Navigator.of(this.context).pop();
                return;
              }
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text(failedL10n.chatFailedToDeleteSession)),
              );
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
