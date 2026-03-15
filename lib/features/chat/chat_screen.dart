import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/session.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'chat_input.dart';
import 'message_widget.dart';
import '../sessions/widgets/session_cards.dart'
    show parseAvatarStyle;
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
  bool _isLoadingMessages = true;
  bool _loadFailed = false;

  bool _didStartInitialLoad = false;
  int _lastDataChangeCounter = 0;
  int _prevMessagesLength = 0;
  int _prevSeenLength = 0;
  late final ValueNotifier<bool> _autoScrollNotifier =
      ValueNotifier<bool>(true);
  bool get _autoScroll => _autoScrollNotifier.value;
  set _autoScroll(bool value) => _autoScrollNotifier.value = value;
  static const double _autoScrollThreshold = 100;

  PermissionMode _permissionMode = PermissionMode.defaultMode;
  ClaudeModel _modelMode = ClaudeModel.defaultModel;
  AIBackendProfile? _selectedProfile;
  List<AIBackendProfile> _availableProfiles = const [];
  Session? _session;
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _metadataJson;
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  int _lastLoadMoreMs = 0;

  // Cached avatar style and settings values to avoid ref.watch in build().
  AvatarStyle? _avatarStyle;
  bool _enterToSend = true;

  // Cached slicing / index data for _buildMessageList.
  List<Map<String, dynamic>>? _cachedVisibleMessages;
  List<Map<String, dynamic>>? _cachedVisibleSource;
  int _cachedMessagesLength = -1;
  int _cachedVisibleCount = -1;

  bool _initialLoadComplete = false;
  final Set<String> _seenMessageIds = {};

  // Pre-computed neighbor cache for message list items (replacing O(N) scans).
  final Map<int, (Map<String, dynamic>?, Map<String, dynamic>?)>
      _neighborCache = {};
  List<Map<String, dynamic>?>? _neighborCacheSource;
  int _neighborCacheLength = -1;

  void _rebuildNeighborCache(List<Map<String, dynamic>?> items) {
    if (identical(items, _neighborCacheSource) &&
        items.length == _neighborCacheLength) {
      return;
    }
    _neighborCacheSource = items;
    _neighborCacheLength = items.length;
    _neighborCache.clear();
    for (var i = 0; i < items.length; i++) {
      Map<String, dynamic>? prev;
      for (var j = i - 1; j >= 0; j--) {
        if (items[j] != null) {
          prev = items[j];
          break;
        }
      }
      Map<String, dynamic>? next;
      for (var j = i + 1; j < items.length; j++) {
        if (items[j] != null) {
          next = items[j];
          break;
        }
      }
      _neighborCache[i] = (prev, next);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialSettings();
    _initializeSyncBackedChat();
    final settings = ref.read(settingsNotifierProvider);
    _avatarStyle = parseAvatarStyle(settings.avatarStyle);
    _enterToSend = settings.agentInputEnterToSend;
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

    // Model mode.
    final flavor = session?.metadata?.flavor;
    var modelMode = ClaudeModel.defaultModel;
    if (savedModelMode != null) {
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(savedModelMode),
        flavor,
      );
    } else if (session?.modelMode != null) {
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(session!.modelMode),
        flavor,
      );
    } else if (settings.lastUsedModelMode != null) {
      // Fall back to the user's last-used model preference so new sessions
      // inherit the model the user most recently picked.
      modelMode = ClaudeModel.normalizeForFlavor(
        ClaudeModel.fromString(settings.lastUsedModelMode),
        flavor,
      );
    }

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

    setState(() {
      _permissionMode = permissionMode;
      _modelMode = modelMode;
      _availableProfiles = deduped;
      _selectedProfile = selectedProfile;
    });
  }

  @override
  void dispose() {
    _dataSyncSubscription?.cancel();
    _messageSyncSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
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

    sync.onSessionVisible(widget.sessionId);
    var success = true;
    try {
      await sync.messagesSync[widget.sessionId]?.awaitQueue().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    _refreshFromSync(markLoaded: true);
    if (!success && _messages.isEmpty) {
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _loadFailed = false;
      _isLoadingMessages = true;
      _didStartInitialLoad = false;
    });
    await _doInitialLoad();
  }

  void _refreshFromSync({bool markLoaded = false}) {
    final latestSession = sync.sessions[widget.sessionId];
    final latestMessages = sync.messagesForSession(widget.sessionId);

    final sessionChanged = latestSession != _session;
    final messagesChanged = !identical(latestMessages, _messages);
    if (!sessionChanged && !messagesChanged && !markLoaded) {
      return;
    }

    if (!mounted) return;

    final hadRequests = _session?.agentState?.requests?.isNotEmpty ?? false;
    final hasRequests =
        latestSession?.agentState?.requests?.isNotEmpty ?? false;
    final newPermission = !hadRequests && hasRequests;

    setState(() {
      _session = latestSession;
      _modelMode = ClaudeModel.normalizeForFlavor(
        _modelMode,
        latestSession?.metadata?.flavor,
      );

      if (messagesChanged && latestMessages.length > _prevMessagesLength) {
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

      if (sessionChanged) {
        _metadataJson = latestSession?.metadata?.toJson();
      }
      if (markLoaded) {
        _isLoadingMessages = false;
        _initialLoadComplete = true;
        for (final m in latestMessages) {
          _seenMessageIds.add(_messageKey(m));
        }
        _prevSeenLength = latestMessages.length;
      } else if (_initialLoadComplete) {
        final oldLen = _prevSeenLength;
        final newLen = latestMessages.length;
        if (newLen > oldLen) {
          for (var i = oldLen; i < newLen; i++) {
            _seenMessageIds.add(_messageKey(latestMessages[i]));
          }
        }
        _prevSeenLength = newLen;
      }
    });

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
      setState(() {
        _autoScroll = nearBottom;
      });
    }

    if (pos.pixels >= pos.maxScrollExtent - 300) {
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
    final availableModels = ClaudeModel.availableForFlavor(
      _session?.metadata?.flavor,
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
          avatarStyle: parseAvatarStyle(
            ref
                .watch(settingsNotifierProvider)
                .avatarStyle,
          ),
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
                  ExcludeSemantics(
                    excluding: _autoScroll || _isLoadingMessages,
                    child: IgnorePointer(
                      ignoring: _autoScroll || _isLoadingMessages,
                      child: AnimatedOpacity(
                        opacity: (!_autoScroll && !_isLoadingMessages)
                            ? 1.0
                            : 0.0,
                        duration: AppDuration.normal,
                        curve: AppCurve.standard,
                        child: AnimatedScale(
                          scale: (!_autoScroll && !_isLoadingMessages)
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
                                  setState(() => _autoScroll = true);
                                  _scrollToBottom();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
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
              onAbort: _abortSession,
              enterToSend: ref
                  .watch(settingsNotifierProvider)
                  .agentInputEnterToSend,
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
    setState(() => _modelMode = normalized);
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveModelMode(widget.sessionId, normalized.modeString);
  }

  void _onProfileChanged(AIBackendProfile? profile) {
    setState(() => _selectedProfile = profile);
    ref
        .read(chatActionNotifierProvider.notifier)
        .saveProfile(widget.sessionId, profile?.id);
  }

  static const _abortReason =
      "The user doesn't want to proceed with this tool "
      'use. The tool use was rejected (eg. if it was a '
      'file edit, the new_string was NOT written to the '
      'file). STOP what you are doing and wait for the '
      'user to tell you how to proceed.';

  Future<void> _abortSession() async {
    await ref
        .read(chatActionNotifierProvider.notifier)
        .abortSession(widget.sessionId, reason: _abortReason);
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
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(
                    alpha: AppOpacity.subtle,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
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
        return RepaintBoundary(
          key: ValueKey(messageKey),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: MessageWidget(
              messageData: message,
              isFromCurrentUser: message['role'] == 'user',
              metadata: metadataJson,
              messages: _messages,
              sessionId: widget.sessionId,
              isSessionOnline:
                  (_session?.isOnline ?? false) ||
                  ((_session?.metadata?.machineId?.isNotEmpty ?? false) &&
                      (_session?.metadata?.path?.isNotEmpty ?? false)),
              onOptionPress: _onOptionPress,
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
            modelMode: _modelMode.modeString,
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    unawaited(TtsService().stop());

    if (text == '/clear') {
      _controller.clear();
      unawaited(DraftStorage().removeDraft(widget.sessionId));
      setState(() {
        _isSending = true;
        _visibleCount = _pageSize;
        _autoScroll = true;
      });
      try {
        final sentSessionId = await ref
            .read(chatActionNotifierProvider.notifier)
            .sendMessage(
              widget.sessionId,
              text,
              permissionMode: _permissionMode.toModeString(),
              modelMode: _modelMode.modeString,
            );
        if (_followRedirectedSession(sentSessionId)) {
          return;
        }
        _refreshFromSync();
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          setState(() => _controller.text = text);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatFailedToClear(e.toString())),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    setState(() {
      _controller.clear();
      _autoScroll = true;
    });

    unawaited(DraftStorage().removeDraft(widget.sessionId));

    try {
      final sentSessionId = await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(
            widget.sessionId,
            text,
            displayText: text,
            permissionMode: _permissionMode.toModeString(),
            modelMode: _modelMode.modeString,
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
        _controller.text = text;
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
                  .read(chatActionNotifierProvider.notifier)
                  .deleteSession(widget.sessionId);
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
