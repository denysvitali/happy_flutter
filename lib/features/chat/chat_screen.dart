import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show Breadcrumb, Hint, Sentry, SentryLevel;

import '../../core/components/tablet/master_detail_scaffold.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/session.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/logger_service.dart' show LogLevel, logger;
import '../../core/services/message_cache_service.dart';
import '../../core/services/session_activity_coordinator.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_color_scheme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/scroll_edge_fade.dart';
import '../../core/utils/wire_parsers.dart';
import '../../core/widgets/sync_progress_bar.dart';
import '../sessions/widgets/session_cards.dart' show parseAvatarStyle;
import 'agent_conversation_screen.dart';
import 'chat_input.dart';
import 'chat_tts_gate.dart';
import 'helpers/chat_dialogs.dart';
import 'message_detail_screen.dart';
import 'message_widget.dart';
import 'session_file_viewer_screen.dart';
import 'session_files_screen.dart';
import 'session_info_screen.dart';
import 'widgets/agent_event_widget.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_loading_shimmer.dart';
import 'widgets/cleared_divider.dart';
import 'widgets/conversation_start_label.dart';
import 'widgets/empty_chat_view.dart';
import 'widgets/permission_mode_selector.dart';
import 'widgets/retry_error_view.dart';
import 'widgets/scroll_to_bottom_pill.dart';
import 'widgets/session_tasks_banner.dart';
import 'widgets/thinking_pill.dart';
import 'widgets/tts_playback_bar.dart';

// NOTE: chat_screen uses `part` files (_chat_screen_actions.dart, etc.)
// because Dart's library-private (`_`) visibility is required for
// _ChatScreenState's private member access across files. Converting to
// regular imports would require making those members public, which
// violates the project's preference for minimal public APIs.
// LSP tools may not resolve definitions across part boundaries.

part '_chat_screen_actions.dart';
part '_chat_screen_builders.dart';

/// Identifies which detail pane (if any) is currently selected when the
/// chat screen is rendered as a master-detail layout on desktop-width
/// viewports.
enum _ChatDetailKind {
  none,
  messageDetail,
  sessionInfo,
  sessionFiles,
  agent,
  fileViewer,
}

class _SessionSendIssue {
  const _SessionSendIssue({
    required this.title,
    required this.message,
    required this.snackBarText,
    required this.blocksSend,
  });

  final String title;
  final String message;
  final String snackBarText;
  final bool blocksSend;
}

/// Chat screen for a session
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.sessionId, this.onBack, super.key});
  final String sessionId;
  final VoidCallback? onBack;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<void>? _dataSyncSubscription;
  StreamSubscription<String>? _messageSyncSubscription;
  StreamSubscription<String>? _paginationErrorSubscription;
  bool _isSending = false;
  bool _isAborting = false;
  bool _isLoadingMessages = true;
  bool _loadFailed = false;

  bool _didStartInitialLoad = false;
  Timer? _loadingSafetyTimer;
  int _lastDataChangeCounter = -1;
  int _prevMessagesLength = 0;
  int _prevSeenLength = 0;
  late final ValueNotifier<bool> _autoScrollNotifier = ValueNotifier<bool>(
    true,
  );
  late final ValueNotifier<int> _messagePaneRevision = ValueNotifier<int>(0);
  bool get _autoScroll => _autoScrollNotifier.value;
  set _autoScroll(bool value) => _autoScrollNotifier.value = value;
  static const double _autoScrollThreshold = 100;

  PermissionMode _permissionMode = PermissionMode.defaultMode;
  ChatModelMode _modelMode = ChatModelMode.defaultModel;

  /// The effective model mode string sent to the server.
  /// For provider-owned model modes (GLM, Codex, etc.) this is the raw
  /// provider-specific string stored in [_profileModelOverride].
  /// For Claude profiles this is just [_modelMode.modeString].
  String? get _effectiveModelModeString =>
      _profileModelOverride ?? _modelMode.modeString;

  /// Raw model mode string from storage, used for provider-owned modes.
  /// For Claude profiles, this matches _modelMode.modeString.
  /// For profiles with their own model names, this contains the actual
  /// model string (e.g., 'GLM-5', 'MiniMax-Text-01') while _modelMode
  /// remains ChatModelMode.defaultModel for UI purposes.
  String? _profileModelOverride;
  AIBackendProfile? _selectedProfile;
  List<AIBackendProfile> _availableProfiles = const [];
  List<ChatModelMode> _codexModelModes = const [ChatModelMode.defaultModel];
  String? _codexModelModesMachineId;
  bool _isLoadingCodexModelModes = false;
  Session? _session;
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _metadataJson;

  // Memoized scan results over _messages, recomputed only when the list is
  // reassigned (see _recomputeMessageScanCache). _buildStatusChips runs on
  // every screen build, so it must not re-scan thousands of messages.
  Map<String, dynamic>? _latestUserStatusMessage;
  int _lastVisibleNonSidechainCreatedAt = 0;
  int _debugMaxSeq = -1;
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  int _lastLoadMoreMs = 0;
  bool _canTriggerHistoryLoad = true;
  bool _isAdjustingHistoryScroll = false;
  double? _lastScrollMaxExtent;
  double? _lastScrollPixels;
  static const double _historyLoadThreshold = 300;

  // Cached slicing / index data for _buildMessageList.
  List<Map<String, dynamic>>? _cachedVisibleMessages;
  List<Map<String, dynamic>>? _cachedVisibleSource;
  int _cachedMessagesLength = -1;
  int _cachedVisibleCount = -1;
  List<Map<String, dynamic>?>? _cachedListItems;
  List<Map<String, dynamic>>? _cachedListItemsSource;
  int _cachedListItemsVisibleCount = -1;
  bool? _cachedListItemsHideToolCalls;
  Map<String, int>? _cachedKeyToListIndex;

  bool _initialLoadComplete = false;
  final Set<String> _seenMessageIds = {};
  final ChatTtsGate _ttsGate = ChatTtsGate();

  // ── Tablet master-detail state (desktop-width only) ──────────────────────
  // Tracks which detail pane is currently selected when the chat screen is
  // wide enough to host its own master-detail layout.
  _ChatDetailKind _detailKind = _ChatDetailKind.none;
  String? _detailMessageId;
  Map<String, dynamic>? _detailMessageData;
  String? _detailFilePath;
  String? _detailFileContent;

  // Track when the actual messages list changes (not just rebuilds)
  List<Map<String, dynamic>>? _lastMessagesList;
  int _lastMessageFingerprint = 0;

  // Pre-computed neighbor cache for message list items (replacing O(N)
  // scans).
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

    // Compute a lightweight hash to detect content changes without O(N) scan.
    // We combine length + first/last item identity for a cheap but effective
    // check.
    final newHash =
        items.length ^
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

    // For each non-null index, find prev/next from the nonNullIndices list
    // - O(N)
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
      // Cap initial render window to _pageSize so sessions with large
      // caches (up to _maxCachedMessages=200) don't build all widgets
      // in the first frame.
      final initialVisible = cached.length < _pageSize
          ? cached.length
          : _pageSize;
      setState(() {
        _messages = cached;
        _recomputeMessageScanCache();
        _isLoadingMessages = false;
        // Mark cached messages as seen so they don't animate
        for (final m in cached) {
          _seenMessageIds.add(_messageKey(m));
        }
        _prevSeenLength = cached.length;
        _visibleCount = initialVisible;
      });
      if (logger.shouldLog(LogLevel.debug)) {
        logger.debug(
          '[ChatScreen] Loaded ${cached.length} cached messages for '
          'session ${widget.sessionId} '
          'visibleCount=$_visibleCount',
        );
      }
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'ChatScreen: initState cache hit',
          category: 'chat.load',
          data: {
            'sessionId': widget.sessionId,
            'cachedCount': cached.length,
            'visibleCount': _visibleCount,
          },
        ),
      );
    }
    unawaited(_loadCachedMessagesAsyncIfNeeded());

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

  Future<void> _loadCachedMessagesAsyncIfNeeded() async {
    if (_messages.isNotEmpty) return;
    final cached = await MessageCacheService().getMessagesAsync(
      widget.sessionId,
    );
    if (!mounted || cached.isEmpty || _messages.isNotEmpty) return;
    final initialVisible = cached.length < _pageSize
        ? cached.length
        : _pageSize;
    setState(() {
      _messages = cached;
      _recomputeMessageScanCache();
      _isLoadingMessages = false;
      for (final m in cached) {
        _seenMessageIds.add(_messageKey(m));
      }
      _prevSeenLength = cached.length;
      _visibleCount = initialVisible;
    });
  }

  @override
  void dispose() {
    _loadingSafetyTimer?.cancel();
    _dataSyncSubscription?.cancel();
    _messageSyncSubscription?.cancel();
    _paginationErrorSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _autoScrollNotifier.dispose();
    _messagePaneRevision.dispose();
    TtsService().stop();
    // Allow the session activity notification to surface again now
    // that the user has left the chat screen.
    unawaited(sessionActivityCoordinator.setVisibleSession(null));
    // Tell sync the chat is no longer visible so it can tear down the
    // per-session message-sync timer and stop background fetches.
    unawaited(sync.onSessionInvisible());
    super.dispose();
  }

  Future<void> _initializeSyncBackedChat() async {
    _messageSyncSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) {
          if (mounted) _refreshFromSync();
        });
    _dataSyncSubscription = sync.onDomainChanged
        .where((domain) => domain == SyncDomain.sessions)
        .listen((_) {
          if (!mounted) return;
          final counter = sync.domainChangeCounter(SyncDomain.sessions);
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

    _paginationErrorSubscription = sync.onPaginationError
        .where((id) => id == widget.sessionId)
        .listen((_) {
          if (mounted) {
            // Defer until after the first frame so context is available.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.chatFailedToLoadMessages),
                  duration: const Duration(seconds: 4),
                ),
              );
            });
          }
        });

    if (!sync.isInitialized) {
      return;
    }

    await _doInitialLoad();
  }

  void _refreshFromSync({bool markLoaded = false, bool loadFailed = false}) {
    final latestSession = sync.sessions[widget.sessionId];
    final latestMessages = sync.messagesForSession(widget.sessionId);

    final sessionChanged = latestSession != _session;
    var messagesChanged = !identical(latestMessages, _messages);

    // Always compute fingerprint for same-length lists.  Unmodifiable
    // view caches can be mutated in place (e.g. when the underlying
    // _sessionMessages list is replaced but the view wrapper is reused),
    // so identical() alone is not sufficient.
    final latestMessageFingerprint =
        latestMessages.length == _messages.length &&
            _lastMessageFingerprint != 0
        ? _computeMessageFingerprint(latestMessages)
        : _computeMessageFingerprint(latestMessages);

    if (latestMessages.length == _messages.length &&
        _lastMessageFingerprint != 0) {
      messagesChanged = latestMessageFingerprint != _lastMessageFingerprint;
    }

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
    if (!messagesChanged && latestMessages.isNotEmpty && _messages.isEmpty) {
      messagesChanged = true;
    }

    if (logger.shouldLog(LogLevel.debug)) {
      logger.debug(
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
    }

    if (!sessionChanged && !messagesChanged && !markLoaded && !loadFailed) {
      return;
    }

    if (!mounted) return;

    if (messagesChanged && !identical(latestMessages, _lastMessagesList)) {
      _invalidateNeighborCache();
      _lastMessagesList = latestMessages;
    }

    final hadRequests = _session?.agentState?.requests?.isNotEmpty ?? false;
    final hasRequests =
        latestSession?.agentState?.requests?.isNotEmpty ?? false;
    final newPermission = !hadRequests && hasRequests;

    final needsScreenRebuild = sessionChanged || messagesChanged;
    void applyUpdates() {
      if (sessionChanged) {
        _session = latestSession;
        _metadataJson = latestSession?.metadata?.toJson();
      }

      // Re-normalize model only when the session's flavor actually changed
      // to avoid overwriting the user's model selection on every sync event.
      if (sessionChanged) {
        _modelMode = ChatModelMode.normalizeForFlavor(
          _modelMode,
          latestSession?.metadata?.flavor,
        );
        unawaited(_refreshCodexModelModes(latestSession));
      }

      // Handle markLoaded unconditionally — the HTTP fetch completed even if
      // no messages changed (e.g. empty session or subagent session).
      if (markLoaded) {
        _isLoadingMessages = false;
        _initialLoadComplete = true;
        // Seed the TTS baseline so the first server fetch doesn't replay
        // the most recent historical reply on entry.
        _ttsGate.markInitialLoadComplete(latestMessages);
        // Always sync _prevMessagesLength so the next messagesChanged
        // adjustment is correct (prevMessagesLength is only set inside the
        // messagesChanged block below, so it must be set here too).
        _prevMessagesLength = latestMessages.length;
        _visibleCount = _clampVisibleCount(latestMessages.length);
      }

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
        _recomputeMessageScanCache();
        _lastMessageFingerprint = latestMessageFingerprint;
        _prevMessagesLength = latestMessages.length;

        if (markLoaded) {
          _markMessagesAsSeen(latestMessages, 0, latestMessages.length);
        } else if (latestMessages.isNotEmpty) {
          // Cached messages arrived from MMKV (via onSessionVisible) — dismiss
          // the shimmer immediately instead of waiting for the HTTP
          // round-trip.
          _isLoadingMessages = false;
          if (!_initialLoadComplete) {
            // First time we see messages (from cache) — mark them as seen so
            // they don't animate. Only genuinely new messages should animate.
            _markMessagesAsSeen(latestMessages, 0, latestMessages.length);
          } else {
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
    }

    if (needsScreenRebuild) {
      setState(applyUpdates);
    } else {
      applyUpdates();
      _bumpMessagePaneRevision();
    }

    // Post-state-update side effects
    if (messagesChanged && _autoScroll) {
      _scrollToBottom();
    }

    if (newPermission) {
      _scrollToBottom();
    }

    if (messagesChanged) {
      final settings = ref.read(settingsNotifierProvider);
      final speech = _ttsGate.evaluate(
        messages: latestMessages,
        ttsEnabled: settings.ttsEnabled,
      );
      if (speech != null) {
        // Use enqueueSpeak so a new reply arriving while the user is
        // still listening to an earlier one doesn't interrupt — the
        // newer reply plays after the current one finishes.
        unawaited(
          TtsService().enqueueSpeak(
            speech,
            token: _ttsGate.lastSpokenMessageId,
            useOffline: settings.ttsUseOffline,
            offlineVoiceId: settings.ttsVoiceId,
          ),
        );
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

  int _initialVisibleCount(int messageCount) =>
      messageCount < _pageSize ? messageCount : _pageSize;

  int _clampVisibleCount(int messageCount) {
    if (messageCount == 0) return _pageSize;
    final minVisible = _initialVisibleCount(messageCount);
    return _visibleCount.clamp(minVisible, messageCount).toInt();
  }

  /// Invalidates the neighbor cache. Call when the messages list changes.
  void _invalidateNeighborCache() {
    _neighborCache.clear();
    _neighborCacheSource = null;
    _neighborCacheLength = -1;
    _neighborCacheSourceHash = 0;
    _cachedListItems = null;
    _cachedListItemsSource = null;
    _cachedListItemsVisibleCount = -1;
    _cachedListItemsHideToolCalls = null;
    _cachedKeyToListIndex = null;
  }

  void _bumpMessagePaneRevision() {
    _messagePaneRevision.value++;
  }

  String _messageKey(Map<String, dynamic> m) =>
      m['id'] as String? ?? m['toolUseId'] as String? ?? '';

  int _computeMessageFingerprint(List<Map<String, dynamic>> messages) {
    // Hash length + first message + last N messages. This is O(1) instead
    // of O(N) while still catching appends, streaming content updates,
    // state changes on the newest message, and prepends (older page loads).
    const tailSize = 5;
    final len = messages.length;
    var hash = len;
    if (len == 0) return hash;

    hash = _hashMessage(hash, messages.first);

    final start = (len - tailSize).clamp(0, len);
    for (var i = start; i < len; i++) {
      hash = _hashMessage(hash, messages[i]);
    }
    return hash;
  }

  static int _hashMessage(int seed, Map<String, dynamic> message) {
    final content = message['content'] ?? message['text'];
    final contentHash = switch (content) {
      final String text => Object.hash(text.length, text.hashCode),
      final List<dynamic> list => list.length,
      final Map<dynamic, dynamic> map => map.length,
      _ => content?.hashCode ?? 0,
    };
    return Object.hash(
      seed,
      message['id'],
      message['toolUseId'],
      message['seq'],
      message['role'],
      message['kind'],
      message['state'],
      message['isThinking'],
      message['sendStatus'],
      contentHash,
    );
  }

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

    _preserveHistoryEdgeOnExtentGrowth(pos);

    final nearBottom = pos.pixels <= _autoScrollThreshold;
    if (nearBottom != _autoScroll) {
      // Updating the ValueNotifier directly — no setState needed,
      // only the pill's ValueListenableBuilder will rebuild.
      _autoScroll = nearBottom;
    }

    // In this reverse ListView, index 0 is the newest message and is laid out
    // at the visual bottom.
    // At pixels = 0 (minScrollExtent): viewing newest messages.
    // At pixels = maxScrollExtent: viewing oldest messages at history top.
    //
    // Older messages are loaded when the user scrolls near maxScrollExtent.
    final atHistoryEdge =
        pos.pixels >= pos.maxScrollExtent - _historyLoadThreshold;
    if (!atHistoryEdge) {
      _canTriggerHistoryLoad = true;
    }

    if (atHistoryEdge &&
        _canTriggerHistoryLoad &&
        pos.isScrollingNotifier.value) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastLoadMoreMs >= 200) {
        _lastLoadMoreMs = now;
        _canTriggerHistoryLoad = false;
        _loadMore();
      }
    }

    _rememberScrollMetrics(pos);
  }

  void _preserveHistoryEdgeOnExtentGrowth(ScrollPosition pos) {
    if (_isAdjustingHistoryScroll || _isLoadingMore) return;

    final previousMax = _lastScrollMaxExtent;
    final previousPixels = _lastScrollPixels;
    if (previousMax == null || previousPixels == null) return;

    final extentDelta = pos.maxScrollExtent - previousMax;
    if (extentDelta <= 1) return;

    final wasNearHistoryEdge =
        previousPixels >= previousMax - _historyLoadThreshold;
    if (!wasNearHistoryEdge) return;

    final previousDistance = (previousMax - previousPixels)
        .clamp(0.0, double.infinity)
        .toDouble();
    final target = (pos.maxScrollExtent - previousDistance)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if ((target - pos.pixels).abs() <= 1) return;

    _isAdjustingHistoryScroll = true;
    try {
      pos.jumpTo(target);
    } finally {
      _isAdjustingHistoryScroll = false;
    }
  }

  void _rememberScrollMetrics(ScrollPosition pos) {
    _lastScrollMaxExtent = pos.maxScrollExtent;
    _lastScrollPixels = pos.pixels;
  }

  bool _isAtHistoryEdge() {
    if (!_scrollController.hasClients) return false;
    final pos = _scrollController.position;
    return pos.pixels >= pos.maxScrollExtent - _historyLoadThreshold;
  }

  void _continueLocalHistoryLoadIfStillAtEdge() {
    if (!mounted || _isLoadingMore || !_isAtHistoryEdge()) return;
    _canTriggerHistoryLoad = true;
    _loadMore();
  }

  void _loadMore() {
    if (_isLoadingMore) return;

    if (_visibleCount < _messages.length) {
      _isLoadingMore = true;
      final keepAtHistoryEdge = _isAtHistoryEdge();
      final targetCount = (_visibleCount + _pageSize).clamp(
        0,
        _messages.length,
      );
      _visibleCount = targetCount;
      _bumpMessagePaneRevision();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (keepAtHistoryEdge && _scrollController.hasClients) {
          _isAdjustingHistoryScroll = true;
          try {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          } finally {
            _isAdjustingHistoryScroll = false;
          }
        }
        _isLoadingMore = false;
        _continueLocalHistoryLoadIfStillAtEdge();
      });
      return;
    }

    if (sync.hasOlderMessages(widget.sessionId) &&
        !sync.isLoadingOlderMessages(widget.sessionId)) {
      _isLoadingMore = true;
      sync.fetchOlderMessages(widget.sessionId).whenComplete(() {
        if (mounted) {
          _isLoadingMore = false;
          _bumpMessagePaneRevision();
        }
      });
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

  String _formatLastSeenLabel(BuildContext context, int activeAt) {
    final l10n = context.l10n;
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(activeAt);
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

  _SessionSendIssue? get _sessionSendIssue {
    final session = _session;
    if (session == null || !session.hasLifecycleError) return null;
    final detail = _formatLifecycleError(session.metadata?.lifecycleStateError);
    final canRestore = session.canAttemptLifecycleRestore;
    final detailText = detail == null ? '' : ' $detail';
    final message = canRestore
        ? 'The local agent process is gone for this session.$detailText '
              'Sending a message will try to restart it before delivery.'
        : 'The local agent process is gone for this session.$detailText '
              'No restore target is available, so new messages cannot '
              'be delivered.';
    return _SessionSendIssue(
      title: 'Session process stopped',
      message: message,
      snackBarText:
          'This session cannot respond because its local '
          'agent process stopped and no restore target is available. '
          'Start a new session to continue.',
      blocksSend: !canRestore,
    );
  }

  String? _formatLifecycleError(String? error) {
    final trimmed = error?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.contains('without a live local process')) {
      return 'No live local process is attached to it.';
    }
    const maxLength = 140;
    if (trimmed.length <= maxLength) return 'Reason: $trimmed';
    return 'Reason: ${trimmed.substring(0, maxLength)}...';
  }

  void _showSendBlockedSnackBar(_SessionSendIssue issue) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(issue.snackBarText)));
  }

  /// True when the newest visible agent message is a text bubble —
  /// meaning text is already streaming (pill should hide).
  bool _isNewestMessageAgentText() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m['isSidechain'] == true) continue;
      if (m['role'] != 'agent') return false;
      final kind = m['kind'] as String?;
      return kind == null || kind == 'text';
    }
    return false;
  }

  /// Name of the most recent tool-call message, if any.
  String? _lastRunningToolName() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['kind'] == 'tool-call') {
        return _messages[i]['name'] as String?;
      }
    }
    return null;
  }

  /// Recomputes the memoized backward scans over [_messages]:
  /// the latest user message carrying a sendStatus, the createdAt of the
  /// last visible (non-sidechain) message, and (debug only) the max seq.
  ///
  /// Must be called whenever [_messages] is reassigned. Keeping these in
  /// fields lets _buildStatusChips stay O(1) per build instead of
  /// re-scanning the full list (up to 3000 entries) on every rebuild.
  void _recomputeMessageScanCache() {
    Map<String, dynamic>? latestUserStatus;
    var lastVisibleCreatedAt = 0;
    var foundVisible = false;
    var maxSeq = -1;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      if (!foundVisible && message['isSidechain'] != true) {
        final ts = message['createdAt'];
        if (ts is int) {
          lastVisibleCreatedAt = ts;
          foundVisible = true;
        }
      }
      if (latestUserStatus == null && message['role'] == 'user') {
        final status = message['sendStatus'] as String?;
        if (status != null && status.isNotEmpty) {
          latestUserStatus = message;
        }
      }
      if (kDebugMode) {
        // Debug seq watermark needs the full list; skip early exit.
        final s = message['seq'];
        if (s is int && s > maxSeq) maxSeq = s;
      } else if (foundVisible && latestUserStatus != null) {
        break;
      }
    }
    _latestUserStatusMessage = latestUserStatus;
    _lastVisibleNonSidechainCreatedAt = lastVisibleCreatedAt;
    _debugMaxSeq = maxSeq;
  }

  List<ChatAppBarStatusChip> _buildStatusChips(BuildContext context) {
    final session = _session;
    if (session == null) return const [];

    final chips = <ChatAppBarStatusChip>[];
    final colorScheme = Theme.of(context).colorScheme;
    final hasRequests = session.agentState?.requests?.isNotEmpty ?? false;
    final isReady = sync.isSessionReadyForMessages(session.id);
    final lifecycleState = session.effectiveLifecycleState;
    final lifecycleSince = session.metadata?.lifecycleStateSince;
    final lifecycleIsRecent =
        lifecycleSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleSince < 120000;
    final isConnecting =
        !isReady &&
        lifecycleIsRecent &&
        (lifecycleState == 'starting' || lifecycleState == 'running');
    final sendIssue = _sessionSendIssue;

    if (sendIssue != null) {
      chips.add(
        ChatAppBarStatusChip(
          text: sendIssue.blocksSend ? 'Agent failed' : 'Will restart',
          color: sendIssue.blocksSend ? AppColors.error : AppColors.warning,
          icon: sendIssue.blocksSend
              ? Icons.error_outline_rounded
              : Icons.restart_alt_rounded,
        ),
      );
    } else if (isReady) {
      chips.add(
        const ChatAppBarStatusChip(
          text: 'Online',
          color: AppColors.success,
          showDot: true,
          pulse: true,
        ),
      );
    } else if (isConnecting) {
      chips.add(
        ChatAppBarStatusChip(
          text: 'Connecting',
          color: colorScheme.primary,
          icon: Icons.sync_rounded,
        ),
      );
    } else {
      chips
        ..add(
          ChatAppBarStatusChip(
            text: 'Offline',
            color: colorScheme.outline,
            icon: Icons.cloud_off_rounded,
          ),
        )
        ..add(
          ChatAppBarStatusChip(
            text: _formatLastSeenLabel(context, session.activeAt),
            color: colorScheme.onSurfaceVariant,
            icon: Icons.schedule_rounded,
          ),
        );
    }

    if (hasRequests) {
      chips.add(
        const ChatAppBarStatusChip(
          text: 'Approval needed',
          color: AppColors.warning,
          icon: Icons.shield_outlined,
        ),
      );
    } else if (session.thinking) {
      // When the agent has been "thinking" for a while with no new visible
      // (non-sidechain) message, surface that the work is likely happening
      // inside sub-tasks. Without this signal the chat looks paused — see
      // the long-running session diagnosis on c8400ba… where 2000+ server
      // messages produced almost no visible bubbles.
      const subTaskSwitchMs = 30000;
      final lastVisibleCreatedAt = _lastVisibleNonSidechainCreatedAt;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final stale =
          lastVisibleCreatedAt > 0 &&
          nowMs - lastVisibleCreatedAt > subTaskSwitchMs;
      chips.add(
        ChatAppBarStatusChip(
          text: stale ? 'Working on sub-tasks' : 'Thinking',
          color: colorScheme.primary,
          showDot: !stale,
          icon: Icons.account_tree_outlined,
        ),
      );
    }

    // Debug-only seq watermark — proves the session is alive when the
    // visible chat looks idle. Highest seq we have decrypted (incl.
    // sidechain). The user requested this after observing seq=2000+ with
    // few visible messages.
    if (kDebugMode) {
      final maxSeq = _debugMaxSeq;
      if (maxSeq >= 0) {
        chips.add(
          ChatAppBarStatusChip(
            text: 'seq=$maxSeq',
            color: colorScheme.outline,
            icon: Icons.bug_report_outlined,
          ),
        );
      }
    }

    final latestUserMessage = _latestUserStatusMessage;
    final sendStatus = latestUserMessage?['sendStatus'] as String?;
    if (sendStatus != null) {
      switch (sendStatus) {
        case 'sending':
          chips.add(
            ChatAppBarStatusChip(
              text: 'Sending',
              color: colorScheme.onSurfaceVariant,
              icon: Icons.arrow_upward_rounded,
            ),
          );
          break;
        case 'pending':
          chips.add(
            const ChatAppBarStatusChip(
              text: 'Retry queued',
              color: AppColors.warning,
              icon: Icons.schedule_rounded,
            ),
          );
          break;
        case 'failed':
          chips.add(
            const ChatAppBarStatusChip(
              text: 'Not delivered',
              color: AppColors.error,
              icon: Icons.error_outline_rounded,
            ),
          );
          break;
      }
    }

    if (_modelMode != ChatModelMode.defaultModel) {
      chips.add(
        ChatAppBarStatusChip(
          text: _modelMode.label,
          color: colorScheme.onSurfaceVariant,
          icon: Icons.tune_rounded,
        ),
      );
    }

    return chips;
  }

  /// Whether the chat screen itself is wide enough to host its own
  /// master-detail layout. Compared against the available pane width (via
  /// `LayoutBuilder`), not the full screen width, so that an embedded chat
  /// (e.g. inside the sessions tablet master-detail) correctly falls back
  /// to single-pane and pushes routes for info/files instead of carving a
  /// second empty detail pane out of its own slot.
  ///
  /// Always single-pane when embedded — `onBack` is set by the embedding
  /// parent (sessions tablet layout) and double-nesting master-detail leaves
  /// an unused empty section visible until the user opens an info pane.
  bool _isChatWide(double availableWidth) {
    if (widget.onBack != null) return false;
    return availableWidth >= AppBreakpoint.desktop;
  }

  void _clearChatDetail() {
    if (_detailKind == _ChatDetailKind.none) return;
    setState(() {
      _detailKind = _ChatDetailKind.none;
      _detailMessageId = null;
      _detailMessageData = null;
      _detailFilePath = null;
      _detailFileContent = null;
    });
  }

  void _showSessionInfoDetail() {
    setState(() {
      _detailKind = _ChatDetailKind.sessionInfo;
      _detailMessageId = null;
      _detailMessageData = null;
      _detailFilePath = null;
      _detailFileContent = null;
    });
  }

  static const Widget _emptyChatDetail = SizedBox.shrink();

  Widget _buildDetailPane() {
    final sid = widget.sessionId;
    switch (_detailKind) {
      case _ChatDetailKind.none:
        return _emptyChatDetail;
      case _ChatDetailKind.sessionInfo:
        return SessionInfoScreen(
          key: ValueKey('detail-info-$sid'),
          sessionId: sid,
          embedded: true,
          onClose: _clearChatDetail,
        );
      case _ChatDetailKind.sessionFiles:
        return SessionFilesScreen(
          key: ValueKey('detail-files-$sid'),
          sessionId: sid,
          embedded: true,
          onClose: _clearChatDetail,
        );
      case _ChatDetailKind.messageDetail:
        final id = _detailMessageId;
        if (id == null) return _emptyChatDetail;
        return MessageDetailScreen(
          key: ValueKey('detail-message-$sid-$id'),
          sessionId: sid,
          messageId: id,
          messageData: _detailMessageData,
          embedded: true,
          onClose: _clearChatDetail,
        );
      case _ChatDetailKind.agent:
        final id = _detailMessageId;
        if (id == null) return _emptyChatDetail;
        return AgentConversationScreen(
          key: ValueKey('detail-agent-$sid-$id'),
          sessionId: sid,
          messageId: id,
          taskData: _detailMessageData,
          embedded: true,
          onClose: _clearChatDetail,
        );
      case _ChatDetailKind.fileViewer:
        final path = _detailFilePath;
        if (path == null) return _emptyChatDetail;
        return SessionFileViewerScreen(
          key: ValueKey('detail-file-$sid-$path'),
          path: path,
          sessionId: sid,
          content: _detailFileContent,
          embedded: true,
          onClose: _clearChatDetail,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableModels = ChatModelMode.availableForProfile(
      flavor: _session?.metadata?.flavor,
      claudeCompatible: _selectedProfile?.compatibility.claude ?? true,
      codexModels: _codexModelModes,
    );

    // Use select() so this build only re-runs when the specific settings
    // fields actually change, not on any settings mutation.
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select((s) => parseAvatarStyle(s.avatarStyle)),
    );
    final enterToSend = ref.watch(
      settingsNotifierProvider.select((s) => s.agentInputEnterToSend),
    );
    final hideToolCalls = ref.watch(
      settingsNotifierProvider.select((s) => s.hideToolCalls),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = _isChatWide(constraints.maxWidth);
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) {
            // Always evaluate canPop at pop-gesture time via the callback.
            // Using !didPop guards on the actual current text, not the
            // build-time value that may have changed between keystrokes.
            return PopScope(
              // Also allow the pop when onBack is set — the custom handler
              // (tablet in-place selection) should consume back presses, not
              // swallow them and leave the user appearing stuck.
              canPop: value.text.trim().isEmpty || widget.onBack != null,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && _controller.text.trim().isNotEmpty) {
                  showUnsentMessageDialog(
                    context,
                    sessionId: widget.sessionId,
                    controller: _controller,
                  );
                }
              },
              child: child!,
            );
          },
          child: Scaffold(
            appBar: ChatAppBar(
              session: _session,
              sessionTitle: _getSessionTitle(),
              statusChips: _buildStatusChips(context),
              machineVitals: _buildMachineVitals(),
              sessionId: widget.sessionId,
              avatarStyle: avatarStyle,
              onInfoTap: () {
                HapticFeedback.lightImpact();
                if (isWide) {
                  _showSessionInfoDetail();
                  return;
                }
                context.pushNamed(
                  'session-info',
                  pathParameters: {'sessionId': widget.sessionId},
                );
              },
              onMenuTap: () => showSessionMenu(
                context,
                sessionId: widget.sessionId,
                onAbort: _abortSession,
              ),
              onBackTap: widget.onBack,
            ),
            body: _buildScaffoldBody(
              isWide: isWide,
              hideToolCalls: hideToolCalls,
              enterToSend: enterToSend,
              availableModels: availableModels,
            ),
          ),
        );
      },
    );
  }

  Widget _buildScaffoldBody({
    required bool isWide,
    required bool hideToolCalls,
    required bool enterToSend,
    required List<ChatModelMode> availableModels,
  }) {
    final master = _buildMasterPane(
      hideToolCalls: hideToolCalls,
      enterToSend: enterToSend,
      availableModels: availableModels,
    );
    if (!isWide) return master;
    return MasterDetailScaffold(
      master: master,
      detail: _buildDetailPane(),
      hasSelection: _detailKind != _ChatDetailKind.none,
      tabletBreakpoint: AppBreakpoint.desktop,
      emptyDetail: _emptyChatDetail,
    );
  }

  Widget _buildMasterPane({
    required bool hideToolCalls,
    required bool enterToSend,
    required List<ChatModelMode> availableModels,
  }) {
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _messagePaneRevision,
            builder: (context, revision, child) {
              return Stack(
                children: [
                  AnimatedSwitcher(
                    duration: AppDuration.normal,
                    child: _isLoadingMessages
                        ? const ChatLoadingShimmer(key: ValueKey('loading'))
                        : _messages.isEmpty
                        ? (_loadFailed
                              ? RetryErrorView(onRetry: _retry)
                              : EmptyChatView(
                                  key: const ValueKey('empty'),
                                  onSuggestionTap: _onSuggestionTap,
                                ))
                        : _buildMessageList(hideToolCalls: hideToolCalls),
                  ),
                  // The scroll-to-bottom pill listens to
                  // _autoScrollNotifier directly so scroll events do NOT
                  // trigger a full _ChatScreenState rebuild.
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
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: SyncProgressBar()),
                  ),
                ],
              );
            },
          ),
        ),
        if (_sessionSendIssue case final issue?)
          _SessionIssueBanner(issue: issue),
        SessionTasksBanner(sessionId: widget.sessionId),
        TtsPlaybackBar(
          onPrev: _ttsPrev,
          onStop: _ttsStop,
          onNext: _ttsNext,
          canGoPrev: _ttsCanGoPrev(),
          canGoNext: _ttsCanGoNext(),
        ),
        ThinkingPill(
          isThinking: _session?.thinking ?? false,
          isTextStreaming:
              (_session?.thinking ?? false) && _isNewestMessageAgentText(),
          lastToolName: _lastRunningToolName(),
          thinkingAt: _session?.thinkingAt,
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
          machineName: _session?.metadata?.host,
          currentPath: _session?.metadata?.path,
          contextSize:
              sync.sessionUsage[widget.sessionId]?['contextSize'] as int?,
          isSessionOnline: _session?.isPresenceOnline ?? false,
          enterToSend: enterToSend,
          lastDeliveryStatus: _latestUserStatusMessage?['sendStatus']
              as String?,
        ),
      ],
    );
  }

  ChatMachineVitals? _buildMachineVitals() {
    final machineId = _session?.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) return null;
    final machine = ref.watch(
      machinesNotifierProvider.select((machines) => machines[machineId]),
    );
    return ChatMachineVitals.fromDaemonState(machine?.daemonState);
  }
}

class _SessionIssueBanner extends StatelessWidget {
  const _SessionIssueBanner({required this.issue});

  final _SessionSendIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final containerColor = issue.blocksSend
        ? cs.errorContainer
        : appColors?.warningContainer ?? cs.tertiaryContainer;
    final borderColor = issue.blocksSend
        ? cs.error
        : appColors?.warning ?? AppColors.warning;
    final foregroundColor = issue.blocksSend
        ? cs.onErrorContainer
        : appColors?.onWarning ?? cs.onTertiaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(color: borderColor.withValues(alpha: 0.22)),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.22)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              issue.blocksSend
                  ? Icons.error_outline_rounded
                  : Icons.restart_alt_rounded,
              size: 18,
              color: foregroundColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    issue.title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    issue.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foregroundColor,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
