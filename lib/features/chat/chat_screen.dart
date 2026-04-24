import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show Breadcrumb, Hint, Sentry, SentryLevel;

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
import '../sessions/widgets/session_cards.dart' show parseAvatarStyle;
import 'chat_input.dart';
import 'helpers/chat_dialogs.dart';
import 'message_widget.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_loading_shimmer.dart';
import 'widgets/cleared_divider.dart';
import 'widgets/conversation_start_label.dart';
import 'widgets/empty_chat_view.dart';
import 'widgets/permission_mode_selector.dart';
import 'widgets/retry_error_view.dart';
import 'widgets/scroll_to_bottom_pill.dart';

// NOTE: chat_screen uses `part` files (_chat_screen_actions.dart, etc.)
// because Dart's library-private (`_`) visibility is required for
// _ChatScreenState's private member access across files. Converting to
// regular imports would require making those members public, which
// violates the project's preference for minimal public APIs.
// LSP tools may not resolve definitions across part boundaries.

part '_chat_screen_actions.dart';
part '_chat_screen_builders.dart';

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
  ClaudeModel _modelMode = ClaudeModel.defaultModel;

  /// The effective model mode string sent to the server.
  /// For non-Claude profiles (GLM, Codex, etc.) this is the raw
  /// provider-specific string stored in [_profileModelOverride].
  /// For Claude profiles this is just [_modelMode.modeString].
  String? get _effectiveModelModeString =>
      _profileModelOverride ?? _modelMode.modeString;

  /// Raw model mode string from storage, used for non-Claude profiles.
  /// For Claude profiles, this matches _modelMode.modeString.
  /// For other profiles (GLM, MiniMax, etc.), this contains the actual
  /// model string (e.g., 'GLM-5', 'MiniMax-Text-01') while _modelMode
  /// remains ClaudeModel.defaultModel for UI purposes.
  String? _profileModelOverride;
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
  List<Map<String, dynamic>?>? _cachedListItems;
  List<Map<String, dynamic>>? _cachedListItemsSource;
  int _cachedListItemsVisibleCount = -1;
  Map<String, int>? _cachedKeyToListIndex;

  bool _initialLoadComplete = false;
  final Set<String> _seenMessageIds = {};

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
      logger.debug(
        '[ChatScreen] Loaded ${cached.length} cached messages for '
        'session ${widget.sessionId} '
        'visibleCount=$_visibleCount',
      );
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

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Session changed: reset all state so the new session loads fresh.
    if (oldWidget.sessionId != widget.sessionId) {
      _dataSyncSubscription?.cancel();
      _messageSyncSubscription?.cancel();
      _loadingSafetyTimer?.cancel();
      _didStartInitialLoad = false;
      _lastDataChangeCounter = -1;
      _lastMessagesList = null;
      _lastMessageFingerprint = 0;
      // Reset UI state
      _isSending = false;
      _isAborting = false;
      _isLoadingMessages = true;
      _loadFailed = false;
      _session = null;
      _messages = const [];
      _visibleCount = _pageSize;
      _isLoadingMore = false;
      _prevMessagesLength = 0;
      _prevSeenLength = 0;
      _initialLoadComplete = false;
      _seenMessageIds.clear();
      _cachedVisibleMessages = null;
      _cachedVisibleSource = null;
      _cachedMessagesLength = -1;
      _cachedVisibleCount = -1;
      _neighborCache.clear();
      _neighborCacheSource = null;
      _neighborCacheLength = -1;
      _neighborCacheSourceHash = 0;
      _controller.clear();
      _permissionMode = PermissionMode.defaultMode;
      _modelMode = ClaudeModel.defaultModel;
      _profileModelOverride = null;
      _selectedProfile = null;
      _metadataJson = null;
    }
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
    final latestMessageFingerprint =
        messagesChanged ||
            latestMessages.length != _messages.length ||
            _lastMessageFingerprint == 0
        ? _computeMessageFingerprint(latestMessages)
        : _lastMessageFingerprint;

    if (messagesChanged &&
        latestMessages.length == _messages.length &&
        latestMessageFingerprint == _lastMessageFingerprint) {
      messagesChanged = false;
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
        _modelMode = ClaudeModel.normalizeForFlavor(
          _modelMode,
          latestSession?.metadata?.flavor,
        );
      }

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
        // adjustment above could not run
        // (_prevMessagesLength > 0 guard failed).
        // Sync _visibleCount here so all loaded messages
        // are visible immediately.
        if (_visibleCount < latestMessages.length) {
          _visibleCount = latestMessages.length;
        }
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

  /// Invalidates the neighbor cache. Call when the messages list changes.
  void _invalidateNeighborCache() {
    _neighborCache.clear();
    _neighborCacheSource = null;
    _neighborCacheLength = -1;
    _neighborCacheSourceHash = 0;
    _cachedListItems = null;
    _cachedListItemsSource = null;
    _cachedListItemsVisibleCount = -1;
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
      final targetCount = (_visibleCount + _pageSize).clamp(
        0,
        _messages.length,
      );
      _visibleCount = targetCount;
      _isLoadingMore = false;
      _bumpMessagePaneRevision();
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

  Map<String, dynamic>? _latestUserMessageWithStatus() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message['role'] != 'user') continue;
      final status = message['sendStatus'] as String?;
      if (status == null || status.isEmpty) continue;
      return message;
    }
    return null;
  }

  List<ChatAppBarStatusChip> _buildStatusChips(BuildContext context) {
    final session = _session;
    if (session == null) return const [];

    final chips = <ChatAppBarStatusChip>[];
    final colorScheme = Theme.of(context).colorScheme;
    final hasRequests = session.agentState?.requests?.isNotEmpty ?? false;
    final isReady = sync.isSessionReadyForMessages(session.id);
    final lifecycleState = session.metadata?.lifecycleState;
    final lifecycleSince = session.metadata?.lifecycleStateSince;
    final lifecycleIsRecent =
        lifecycleSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleSince < 120000;
    final isConnecting =
        !isReady &&
        lifecycleIsRecent &&
        (lifecycleState == 'starting' || lifecycleState == 'running');

    if (isReady) {
      chips.add(
        const ChatAppBarStatusChip(
          text: '',
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
      chips.add(
        ChatAppBarStatusChip(
          text: 'Offline',
          color: colorScheme.outline,
          icon: Icons.cloud_off_rounded,
        ),
      );
      chips.add(
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
      chips.add(
        ChatAppBarStatusChip(
          text: 'Thinking',
          color: colorScheme.primary,
          showDot: true,
        ),
      );
    }

    final latestUserMessage = _latestUserMessageWithStatus();
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

    if (_modelMode != ClaudeModel.defaultModel) {
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

  @override
  Widget build(BuildContext context) {
    final availableModels = ClaudeModel.availableForProfile(
      flavor: _session?.metadata?.flavor,
      claudeCompatible: _selectedProfile?.compatibility.claude ?? true,
    );

    // Use select() so this build only re-runs when the specific settings
    // fields actually change, not on any settings mutation.
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select((s) => parseAvatarStyle(s.avatarStyle)),
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
          sessionId: widget.sessionId,
          avatarStyle: avatarStyle,
          onInfoTap: () {
            HapticFeedback.lightImpact();
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
        ),
        body: Column(
          children: [
            const OfflineBanner(),
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
                            : _buildMessageList(),
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
                    ],
                  );
                },
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
              onAbort: _abortSession,
              isAborting: _isAborting,
              enterToSend: enterToSend,
            ),
          ],
        ),
      ),
    );
  }
}
