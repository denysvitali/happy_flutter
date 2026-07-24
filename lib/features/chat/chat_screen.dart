import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show Breadcrumb, Hint, Sentry, SentryLevel;

import '../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../core/components/tablet/master_detail_scaffold.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/loop.dart';
import '../../core/models/outgoing_image.dart';
import '../../core/models/session.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/logger_service.dart' show LogLevel, logger;
import '../../core/services/message_cache_service.dart';
import '../../core/services/opentelemetry_service.dart';
import '../../core/services/performance_context_service.dart';
import '../../core/services/screen_awake_service.dart';
import '../../core/services/session_activity_coordinator.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/scroll_edge_fade.dart';
import '../../core/utils/wire_parsers.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/sync_progress_bar.dart';
import '../loops/create_loop_sheet.dart';
import '../loops/loop_actions.dart';
import '../sessions/session_avatar.dart' show AvatarStyle;
import '../sessions/widgets/session_cards.dart' show parseAvatarStyle;
import 'agent_conversation_screen.dart';
import 'chat_input.dart';
import 'chat_list_pipeline.dart';
import 'chat_tts_gate.dart';
import 'helpers/chat_dialogs.dart';
import 'loop_command_parser.dart';
import 'message_detail_screen.dart';
import 'message_render_signature.dart';
import 'message_widget.dart';
import 'model_selection_resolver.dart';
import 'send/chat_attachment_controller.dart';
import 'send/chat_send_coordinator.dart';
import 'send/image_attachment_service.dart';
import 'session_file_viewer_screen.dart';
import 'session_files_screen.dart';
import 'session_info_screen.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_messages_body.dart';
import 'widgets/cleared_divider.dart';
import 'widgets/conversation_start_label.dart';
import 'widgets/pending_permission_bar.dart';
import 'widgets/permission_mode_selector.dart';
import 'widgets/scroll_to_bottom_pill.dart';
import 'widgets/session_goal_banner.dart';
import 'widgets/session_issue_banner.dart';
import 'widgets/session_tasks_banner.dart';
import 'widgets/sub_agent_status_banner.dart';
import 'widgets/thinking_stop_bar.dart';
import 'widgets/tts_playback_bar.dart';
import 'widgets/typing_indicator.dart';

// NOTE: chat_screen uses `part` files (_chat_screen_actions.dart, etc.)
// because Dart's library-private (`_`) visibility is required for
// _ChatScreenState's private member access across files. Converting to
// regular imports would require making those members public, which
// violates the project's preference for minimal public APIs.
// LSP tools may not resolve definitions across part boundaries.

part '_chat_screen_actions.dart';
part '_chat_screen_builders.dart';
part '_chat_scroll_to_bottom_overlay.dart';

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

  /// Test-only hook: when non-null, `_loadInitialSettings` awaits it after
  /// the `DraftStorage` reads have resolved but before this resolution is
  /// persisted/applied. Lets widget tests pause the async restore
  /// mid-flight to deterministically simulate a user interacting with a
  /// picker (model, profile, or permission mode) while the restore is
  /// still in progress. See the race-condition coverage in
  /// `chat_screen_test.dart`. Must be reset to `null` in `tearDown` —
  /// it is a static field shared by every `ChatScreen` instance.
  @visibleForTesting
  static Future<void> Function()? testInitialSettingsApplyBarrier;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatAttachmentController _attachmentController =
      ChatAttachmentController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<void>? _dataSyncSubscription;
  StreamSubscription<String>? _messageSyncSubscription;
  StreamSubscription<String>? _paginationErrorSubscription;
  StreamSubscription<AutoRestoreFailure>? _autoRestoreFailureSubscription;
  bool _isSending = false;
  bool _isAborting = false;
  bool _isLoadingMessages = true;
  bool _loadFailed = false;

  bool _didStartInitialLoad = false;
  Timer? _loadingSafetyTimer;

  /// Coalesces high-frequency [onSessionMessagesChanged] ticks during agent
  /// streaming so we rebuild the message list at most ~once per frame budget
  /// instead of once per socket event (was flooding Loki + main-isolate).
  Timer? _messageRefreshDebounce;
  late final VoidCallback _routeListener;
  static const Duration _messageRefreshDebounceWindow = Duration(
    milliseconds: 50,
  );
  int _lastDataChangeCounter = -1;
  int _prevMessagesLength = 0;
  int _prevSeenLength = 0;
  late final ValueNotifier<bool> _autoScrollNotifier = ValueNotifier<bool>(
    true,
  );
  late final ValueNotifier<int> _messagePaneRevision = ValueNotifier<int>(0);
  late final ValueNotifier<int> _chatChromeRevision = ValueNotifier<int>(0);
  late final ValueNotifier<int> _composerRevision = ValueNotifier<int>(0);
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

  /// True once the user interactively changes the model, profile, or
  /// permission mode via [_onModelModeChanged] / [_onProfileChanged] /
  /// [_onPermissionModeChanged]. Guards `_loadInitialSettings` against
  /// clobbering that choice if the async `DraftStorage` read it depends on
  /// is still in flight when the user acts. Without this, the async load
  /// would silently overwrite an interactive pick made a moment earlier.
  bool _userOverrodeModelOrProfile = false;
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

  // Local timestamp of the last onSessionMessagesChanged event for this
  // session. Sidechain children merging into collapsed Task rows fire the
  // stream without producing a new visible message; the status chips use
  // this to show "Working on sub-tasks" when the thinking flag is stale.
  int _lastMessageStreamActivityAt = 0;
  Timer? _screenAwakeReleaseTimer;
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  int _lastLoadMoreMs = 0;
  bool _canTriggerHistoryLoad = true;
  bool _isAdjustingHistoryScroll = false;
  bool _continueHistoryLoadAfterServerPage = false;

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
  int _lastMessageFingerprint = 0;
  int _lastMessagesRevision = -1;

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
    _routeListener = _handleRouteChanged;
    PerformanceContextService().routeListenable.addListener(_routeListener);
    _scrollController.addListener(_onScroll);
    _loadInitialSettings();
    TtsService().currentToken.addListener(_updateScreenAwake);

    // ── Local-first: Load cached messages instantly (0ms delay) ──
    final cached = MessageCacheService().getMessages(widget.sessionId);
    if (cached.isNotEmpty) {
      final initialVisible = _initialVisibleCount(cached.length);
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
    final initialVisible = _initialVisibleCount(cached.length);
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
    PerformanceContextService().routeListenable.removeListener(_routeListener);
    TtsService().currentToken.removeListener(_updateScreenAwake);
    _screenAwakeReleaseTimer?.cancel();
    unawaited(ScreenAwakeService().setEnabled(false));
    _loadingSafetyTimer?.cancel();
    _dataSyncSubscription?.cancel();
    _messageSyncSubscription?.cancel();
    _messageRefreshDebounce?.cancel();
    _paginationErrorSubscription?.cancel();
    _autoRestoreFailureSubscription?.cancel();
    _controller.dispose();
    _attachmentController.dispose();
    _scrollController.dispose();
    _autoScrollNotifier.dispose();
    _messagePaneRevision.dispose();
    _chatChromeRevision.dispose();
    _composerRevision.dispose();
    TtsService().stop();
    // Allow the session activity notification to surface again now
    // that the user has left the chat screen.
    unawaited(sessionActivityCoordinator.setVisibleSession(null));
    // Tell sync the chat is no longer visible so it can tear down the
    // per-session message-sync timer and stop background fetches.
    unawaited(sync.onSessionInvisible(widget.sessionId));
    super.dispose();
  }

  Future<void> _initializeSyncBackedChat() async {
    _messageSyncSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) {
          if (!mounted) return;
          if (!_isChatRouteActive) return;
          _lastMessageStreamActivityAt = DateTime.now().millisecondsSinceEpoch;
          _updateScreenAwake();
          ref.read(sessionUiStateNotifierProvider.notifier).loadFromSync();
          // Debounce: streaming agents emit many message-changed events per
          // second. Immediate setState each time janks the UI; 50ms is under
          // one frame at 60fps and still feels real-time.
          _messageRefreshDebounce?.cancel();
          _messageRefreshDebounce = Timer(_messageRefreshDebounceWindow, () {
            if (!mounted) return;
            _refreshFromSync();
          });
        });
    _dataSyncSubscription = sync.onDomainChanged
        .where((domain) => domain == SyncDomain.sessions)
        .listen((_) {
          if (!mounted) return;
          if (!_isChatRouteActive) return;
          final counter = sync.domainChangeCounter(SyncDomain.sessions);
          if (counter == _lastDataChangeCounter) return;
          _lastDataChangeCounter = counter;
          ref.read(sessionUiStateNotifierProvider.notifier).loadFromSync();
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

    // ROADMAP P0 — surface auto-restore failures to the user.  Without
    // this, `_resolveSendTargetSession`'s catch-all branch POSTed to a
    // broken session and silently swallowed the failure.  We flip the
    // optimistic message to `sendStatus: 'failed'` (preserving its
    // `localId` per the core messaging invariant) and show a snackbar
    // so the user can retry.
    _autoRestoreFailureSubscription = sync.onAutoRestoreFailure
        .where((failure) => failure.sessionId == widget.sessionId)
        .listen(_handleAutoRestoreFailure);

    if (!sync.isInitialized) {
      return;
    }

    await _doInitialLoad();
  }

  bool get _isChatRouteActive {
    final route = PerformanceContextService().currentRoute;
    return route == null || route == 'chat';
  }

  void _handleRouteChanged() {
    _updateScreenAwake();
    if (!mounted || !_isChatRouteActive) return;
    ref.read(sessionUiStateNotifierProvider.notifier).loadFromSync();
    _refreshFromSync();
  }

  void _refreshFromSync({bool markLoaded = false, bool loadFailed = false}) {
    final latestSession = sync.sessions[widget.sessionId];
    final latestMessages = sync.messagesForSession(widget.sessionId);
    final latestRevision = sync.messagesRevision(widget.sessionId);

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

    // The store bumps a per-session revision on every real message-list
    // mutation. Trust it over the tail-of-5 fingerprint, which misses
    // in-place edits to messages outside the tail — the "a message silently
    // goes stale / disappears mid-thread" class of bug.
    final revisionChanged = latestRevision != _lastMessagesRevision;
    if (revisionChanged) {
      messagesChanged = true;
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
    // view cache was cleared during recovery and the
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

    if (messagesChanged) {
      _invalidateNeighborCache();
    }

    final hadRequests = _session?.agentState?.requests?.isNotEmpty ?? false;
    final hasRequests =
        latestSession?.agentState?.requests?.isNotEmpty ?? false;
    final newPermission = !hadRequests && hasRequests;

    final previousDeliveryStatus =
        _latestUserStatusMessage?['sendStatus'] as String?;
    final needsScreenRebuild = sessionChanged;
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
        _lastMessagesRevision = latestRevision;
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
      if (messagesChanged || markLoaded || loadFailed) {
        _bumpMessagePaneRevision();
      }
      if (messagesChanged) {
        _chatChromeRevision.value++;
        final nextDeliveryStatus =
            _latestUserStatusMessage?['sendStatus'] as String?;
        if (nextDeliveryStatus != previousDeliveryStatus) {
          _composerRevision.value++;
        }
      }
    }

    final continueHistoryLoadAfterServerPage =
        messagesChanged && _continueHistoryLoadAfterServerPage;
    if (continueHistoryLoadAfterServerPage) {
      _continueHistoryLoadAfterServerPage = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _continueHistoryLoadIfStillAtEdge(alignToHistoryEdge: true);
      });
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
    _updateScreenAwake();
  }

  void _updateScreenAwake() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final recentlyReceiving =
        _lastMessageStreamActivityAt > 0 &&
        now - _lastMessageStreamActivityAt < 10000;
    final sessionWorking =
        (_session?.active ?? false) &&
        ((_session?.thinking ?? false) || recentlyReceiving);
    final shouldStayAwake =
        _isChatRouteActive && (sessionWorking || TtsService().isSpeaking);
    unawaited(ScreenAwakeService().setEnabled(shouldStayAwake));

    _screenAwakeReleaseTimer?.cancel();
    if (shouldStayAwake &&
        recentlyReceiving &&
        !(_session?.thinking ?? false) &&
        !TtsService().isSpeaking) {
      final remaining = 10000 - (now - _lastMessageStreamActivityAt);
      _screenAwakeReleaseTimer = Timer(
        Duration(milliseconds: remaining.clamp(1, 10000)),
        _updateScreenAwake,
      );
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
      messageCount == 0 ? _pageSize : messageCount.clamp(1, _pageSize).toInt();

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
    return Object.hash(
      seed,
      message['id'],
      message['toolUseId'],
      message['seq'],
      messageRenderSignature(message),
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

  void _continueHistoryLoadIfStillAtEdge({bool alignToHistoryEdge = false}) {
    if (!mounted || _isLoadingMore || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final previousMax = _lastScrollMaxExtent;
    final atCurrentHistoryEdge =
        pos.pixels >= pos.maxScrollExtent - _historyLoadThreshold;
    final atPreviousHistoryEdge =
        previousMax != null &&
        pos.pixels >= previousMax - _historyLoadThreshold;
    if (!atCurrentHistoryEdge && !atPreviousHistoryEdge) return;

    if (alignToHistoryEdge && !atCurrentHistoryEdge) {
      _isAdjustingHistoryScroll = true;
      try {
        pos.jumpTo(pos.maxScrollExtent);
      } finally {
        _isAdjustingHistoryScroll = false;
      }
    }

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
        _continueHistoryLoadIfStillAtEdge();
      });
      return;
    }

    if (sync.hasOlderMessages(widget.sessionId) &&
        !sync.isLoadingOlderMessages(widget.sessionId)) {
      _isLoadingMore = true;
      final revisionBeforeLoad = sync.messagesRevision(widget.sessionId);
      _continueHistoryLoadAfterServerPage = true;
      sync.fetchOlderMessages(widget.sessionId).whenComplete(() {
        if (mounted) {
          _isLoadingMore = false;
          _bumpMessagePaneRevision();
          if (sync.messagesRevision(widget.sessionId) == revisionBeforeLoad) {
            _continueHistoryLoadAfterServerPage = false;
          }
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

  _SessionSendIssue? get _sessionSendIssue {
    final session = _session;
    if (session == null || !session.hasLifecycleError) return null;
    final detail = _formatLifecycleError(session.metadata?.lifecycleStateError);
    final canRestore = session.canAttemptLifecycleRestore;
    final detailText = detail == null ? '' : ' $detail';
    final message = canRestore
        ? 'The agent process failed or stopped for this session.$detailText '
              'Sending a message will try to restart it before delivery.'
        : 'The agent process failed or stopped for this session.$detailText '
              'No restore target is available, so new messages cannot '
              'be delivered.';
    return _SessionSendIssue(
      title: 'Session agent failed',
      message: message,
      snackBarText:
          'This session cannot respond because its '
          'agent process failed or stopped and no restore target is available. '
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

    final colorScheme = Theme.of(context).colorScheme;
    final sessionUiEntry = ref.watch(sessionUiEntryProvider(session.id));
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final sendIssue = _sessionSendIssue;

    return buildChatStatusChips(
      context: context,
      colorScheme: colorScheme,
      inputs: ChatStatusChipsInputs(
        session: session,
        isReady: sessionUiEntry.isSessionReadyForMessages,
        hasRequests: session.agentState?.requests?.isNotEmpty ?? false,
        sendIssue: sendIssue == null
            ? null
            : SendIssue(
                title: sendIssue.title,
                message: sendIssue.message,
                blocksSend: sendIssue.blocksSend,
              ),
        latestUserMessage: _latestUserStatusMessage,
        lastVisibleNonSidechainCreatedAt: _lastVisibleNonSidechainCreatedAt,
        debugMaxSeq: _debugMaxSeq,
        modelMode: resolveSessionDisplayModel(session.modelMode),
        lastMessageStreamActivityAt: _lastMessageStreamActivityAt,
        isStopping: _isAborting,
        isReconnecting: connectionStatus == ConnectionStatus.connecting,
      ),
    );
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
    // When the selected profile supplies its own Codex model (Azure
    // OpenAI, Qwen Token Plan gateway, etc.) the model slug is fixed by
    // the provider, but the user can still vary the reasoning effort.
    // Hand the picker the provider-owned model so it offers an effort
    // selector instead of the machine's OpenAI catalog.
    String? providerOwnedCodexModel;
    if (_session?.metadata?.flavor == 'codex' &&
        profileOwnsRawCodexModel(_selectedProfile)) {
      final raw = _profileModelOverride ?? _selectedProfile?.defaultModelMode;
      if (raw != null &&
          raw.trim().isNotEmpty &&
          raw.trim() != ChatModelMode.defaultModel.modeString) {
        providerOwnedCodexModel = raw;
      }
    }

    final availableModels = ChatModelMode.availableForProfile(
      flavor: _session?.metadata?.flavor,
      claudeCompatible: _selectedProfile?.compatibility.claude ?? true,
      allowClaudeAliases: !profileUsesThirdPartyAnthropicBaseUrl(
        _selectedProfile,
      ),
      codexModels: _codexModelModes,
      providerOwnedCodexModel: providerOwnedCodexModel,
      profileModels: _selectedProfile?.models,
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
            appBar: PreferredSize(
              preferredSize: _buildChatAppBar(
                context: context,
                isWide: isWide,
                avatarStyle: avatarStyle,
              ).preferredSize,
              child: ValueListenableBuilder<int>(
                valueListenable: _chatChromeRevision,
                builder: (context, revision, child) => _buildChatAppBar(
                  context: context,
                  isWide: isWide,
                  avatarStyle: avatarStyle,
                ),
              ),
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
    final sessionUiEntry = ref.watch(sessionUiEntryProvider(widget.sessionId));
    // Banner priority (top → bottom, limited stack):
    // offline → sub-agent → issue → (goal/tasks only if no issue) →
    // permission sticky → TTS → thinking+stop → input
    return Column(
      children: [
        const OfflineBanner(),
        // Sticky sub-agent status banner. Re-renders on every
        // sync.onDataChanged tick via its own StatefulWidget so the
        // running/total counts stay current without invalidating the
        // chat list. Hides itself when no sub-agents are present.
        SubAgentStatusBanner(sessionId: widget.sessionId),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _messagePaneRevision,
            builder: (context, revision, child) {
              return Stack(
                children: [
                  AnimatedSwitcher(
                    duration: AppDuration.normal,
                    child: ChatMessagesBody(
                      isLoading: _isLoadingMessages,
                      messages: _messages,
                      loadFailed: _loadFailed,
                      onRetry: _retry,
                      onSuggestionTap: _onSuggestionTap,
                      messageList: _buildMessageList(
                        hideToolCalls: hideToolCalls,
                      ),
                    ),
                  ),
                  // The scroll-to-bottom pill listens to
                  // _autoScrollNotifier directly so scroll events do NOT
                  // trigger a full _ChatScreenState rebuild. See
                  // _chat_scroll_to_bottom_overlay.dart.
                  _ChatScrollToBottomOverlay(
                    autoScrollNotifier: _autoScrollNotifier,
                    isLoading: _isLoadingMessages,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _autoScroll = true;
                      _scrollToBottom();
                    },
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
        ValueListenableBuilder<int>(
          valueListenable: _chatChromeRevision,
          builder: (context, revision, child) => _buildActivityChrome(),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _composerRevision,
          builder: (context, revision, child) => ChatInput(
            sessionId: widget.sessionId,
            controller: _controller,
            attachmentController: _attachmentController,
            onSend: _sendMessage,
            isSending: _isSending,
            permissionMode: _permissionMode,
            onPermissionModeChanged: _onPermissionModeChanged,
            modelMode: _modelMode,
            availableModels: availableModels,
            availableSlashCommands:
                _session?.metadata?.slashCommands ?? const [],
            onModelModeChanged: _onModelModeChanged,
            selectedProfile: _selectedProfile,
            availableProfiles: _availableProfiles,
            onProfileChanged: _onProfileChanged,
            machineName: _session?.metadata?.host,
            currentPath: _session?.metadata?.path,
            contextSize: sessionUiEntry.sessionUsage['contextSize'] as int?,
            isSessionOnline: _session?.isPresenceOnline ?? false,
            enterToSend: enterToSend,
            lastDeliveryStatus:
                _latestUserStatusMessage?['sendStatus'] as String?,
          ),
        ),
      ],
    );
  }

  ChatAppBar _buildChatAppBar({
    required BuildContext context,
    required bool isWide,
    required AvatarStyle? avatarStyle,
  }) {
    return ChatAppBar(
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
    );
  }

  Widget _buildActivityChrome() {
    final hasSendIssue = _sessionSendIssue != null;
    final pendingRequests = _session?.agentState?.requests;
    final hasPendingPermission =
        pendingRequests != null && pendingRequests.isNotEmpty;
    final isThinking = _session?.thinking ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_sessionSendIssue case final issue?)
          SessionIssueBanner(
            issue: SendIssue(
              title: issue.title,
              message: issue.message,
              blocksSend: issue.blocksSend,
            ),
          ),
        if (!hasSendIssue) ...[
          SessionGoalBanner(sessionId: widget.sessionId),
          SessionTasksBanner(sessionId: widget.sessionId),
        ],
        if (hasPendingPermission)
          PendingPermissionBar(
            sessionId: widget.sessionId,
            requests: pendingRequests,
            isSessionOnline: _session?.isPresenceOnline ?? false,
          ),
        TtsPlaybackBar(
          onPrev: _ttsPrev,
          onStop: _ttsStop,
          onNext: _ttsNext,
          canGoPrev: _ttsCanGoPrev(),
          canGoNext: _ttsCanGoNext(),
        ),
        if (isThinking && !_isAborting)
          ThinkingStopBar(onStop: _abortSession),
        if (_isAborting)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Stopping\u2026'),
              ],
            ),
          ),
      ],
    );
  }

  ChatMachineVitals? _buildMachineVitals() {
    final machineId = _session?.metadata?.machineId;
    final machine = ref.watch(
      machinesNotifierProvider.select((machines) => machines[machineId ?? '']),
    );
    return buildChatMachineVitals(
      machineId: machineId,
      daemonState: machine?.daemonState,
    );
  }
}
