import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/sessions_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/utils/session_utils.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import 'session_avatar.dart';
import 'widgets/connection_status_badge.dart';
import 'widgets/empty_sessions_view.dart';
import 'widgets/new_session_dialog.dart';
import 'widgets/session_animations.dart';
import 'widgets/session_cards.dart';
import 'widgets/session_dismissible.dart';
import 'widgets/session_headers.dart';
import 'widgets/session_shimmer.dart';

// ─── Selection state ──────────────────────────────────

/// Immutable selection state shared between the parent
/// screen (AppBar) and the list content via a
/// [ValueNotifier].
class _SelectionState {
  const _SelectionState({
    this.isActive = false,
    this.selectedIds = const {},
    this.isBatchDeleting = false,
  });

  final bool isActive;
  final Set<String> selectedIds;
  final bool isBatchDeleting;

  _SelectionState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
    bool? isBatchDeleting,
  }) {
    return _SelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      isBatchDeleting:
          isBatchDeleting ?? this.isBatchDeleting,
    );
  }
}

bool shouldShowInactiveSessionsSection({
  required bool hideInactive,
  required int activeCount,
  required int inactiveCount,
}) {
  if (inactiveCount == 0) return false;
  if (!hideInactive) return true;
  return activeCount == 0;
}

/// Sessions list screen with date grouping and enhanced
/// status display.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<SessionsScreen> createState() =>
      _SessionsScreenState();
}

class _SessionsScreenState
    extends ConsumerState<SessionsScreen> {
  late AppTab _activeTab;
  StreamSubscription<void>? _syncSubscription;
  final _selectionNotifier = ValueNotifier<_SelectionState>(
    const _SelectionState(),
  );
  final _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _searchDebounce;
  int _lastDataChangeCounter = -1;

  @override
  void initState() {
    super.initState();
    _activeTab = _parseTab(widget.initialTab);
    _selectionNotifier.addListener(_onSelectionChanged);
    Future<void>.microtask(() async {
      await ref
          .read(sessionsNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      // Skip redundant calls when the counter hasn't advanced.
      final counter = sync.dataChangeCounter;
      if (counter == _lastDataChangeCounter) return;
      _lastDataChangeCounter = counter;
      ref
          .read(sessionsNotifierProvider.notifier)
          .loadFromSync();
      ref
          .read(machinesNotifierProvider.notifier)
          .loadFromSync();
      ref
          .read(todoStateNotifierProvider.notifier)
          .loadFromSync();
    });
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  AppTab _parseTab(String? tab) {
    return switch (tab) {
      'inbox' => AppTab.inbox,
      'settings' => AppTab.settings,
      'sessions' => AppTab.sessions,
      _ => AppTab.sessions,
    };
  }

  String _tabToString(AppTab tab) {
    return switch (tab) {
      AppTab.inbox => 'inbox',
      AppTab.sessions => 'sessions',
      AppTab.settings => 'settings',
    };
  }

  void _updateUrlTab(AppTab tab) {
    final router = GoRouter.of(context);
    final currentUri =
        router.routeInformationProvider.value.uri;

    if (currentUri.path == '/sessions') {
      final newTab = _tabToString(tab);
      final newUri = currentUri.replace(
        queryParameters:
            newTab == 'sessions' ? {} : {'tab': newTab},
      );
      router.replace(newUri.toString());
    }
  }

  @override
  void dispose() {
    _selectionNotifier
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inboxBadgeCount = ref.watch(
      friendsNotifierProvider
          .select((s) => s.incomingRequests.length),
    );
    final showInboxDot = ref.watch(
      feedNotifierProvider
          .select((s) => s.unreadCount > 0),
    );

    return PopScope(
      canPop: _activeTab == AppTab.sessions,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _activeTab != AppTab.sessions) {
          setState(() => _activeTab = AppTab.sessions);
          _updateUrlTab(AppTab.sessions);
        } else if (!didPop &&
            _activeTab == AppTab.sessions) {
          final now = DateTime.now();
          if (_lastBackPressTime == null ||
              now.difference(_lastBackPressTime!) >
                  const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.sessionsPressBackToExit,
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context, l10n),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _buildCurrentTabContent()),
          ],
        ),
        bottomNavigationBar: TabBar(
          activeTab: _activeTab,
          onTabPress: (tab) {
            setState(() => _activeTab = tab);
            _updateUrlTab(tab);
          },
          inboxBadgeCount: inboxBadgeCount,
          showInboxBadge: showInboxDot,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (_activeTab == AppTab.sessions) {
      return _buildSessionsAppBar(context, l10n);
    }
    return AppBar(title: Text(_getTabTitle(l10n)));
  }

  PreferredSizeWidget _buildSessionsAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final sel = _selectionNotifier.value;
    if (sel.isActive) {
      return _buildSelectionAppBar(context, l10n, sel);
    }
    return _buildNormalSessionsAppBar(context, l10n);
  }

  AppBar _buildNormalSessionsAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final connectionStatus =
        ref.watch(connectionNotifierProvider);

    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.commonSearch,
            border: InputBorder.none,
          ),
          onChanged: (_) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(
              const Duration(milliseconds: 300),
              () {
                if (mounted) setState(() {});
              },
            );
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClear,
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
        ],
      );
    }

    return AppBar(
      title: Text(l10n.sessionHistoryTitle),
      actions: [
        ConnectionStatusBadge(status: connectionStatus),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.commonSearch,
          onPressed: () =>
              setState(() => _isSearching = true),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.sessionsNew,
          onPressed: () =>
              _showNewSessionDialog(context),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(
    BuildContext context,
    AppLocalizations l10n,
    _SelectionState sel,
  ) {
    final cs = Theme.of(context).colorScheme;
    final allIds = _allSelectableSessionIds();
    final allSelected = allIds.isNotEmpty &&
        allIds.every(sel.selectedIds.contains);
    final hasActiveSelected =
        _hasActiveSessionsInSelection(sel);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.commonCancel,
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        l10n.sessionsSelectedCount(
          sel.selectedIds.length,
        ),
      ),
      actions: [
        TextButton(
          onPressed: sel.isBatchDeleting
              ? null
              : () =>
                  _toggleSelectAll(allIds, allSelected),
          child: Text(
            allSelected
                ? l10n.sessionsDeselectAll
                : l10n.sessionsSelectAll,
          ),
        ),
        if (hasActiveSelected)
          IconButton(
            icon: sel.isBatchDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.archive_outlined),
            tooltip: l10n.sessionsArchive,
            onPressed: (sel.selectedIds.isEmpty ||
                    sel.isBatchDeleting)
                ? null
                : () =>
                    _confirmBatchArchive(context, sel),
          ),
        IconButton(
          icon: sel.isBatchDeleting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.error,
                  ),
                )
              : Icon(
                  Icons.delete_outline,
                  color: cs.error,
                ),
          tooltip: l10n.commonDelete,
          onPressed: (sel.selectedIds.isEmpty ||
                  sel.isBatchDeleting)
              ? null
              : () => _confirmBatchDelete(context, sel),
        ),
      ],
    );
  }

  String _getTabTitle(AppLocalizations l10n) {
    switch (_activeTab) {
      case AppTab.inbox:
        return l10n.tabsInbox;
      case AppTab.sessions:
        return l10n.sessionHistoryTitle;
      case AppTab.settings:
        return l10n.tabsSettings;
    }
  }

  Widget _buildCurrentTabContent() {
    return IndexedStack(
      index: _activeTab.index,
      children: [
        const InboxScreen(),
        _SessionsListContent(
          selectionNotifier: _selectionNotifier,
          searchQuery: _searchController.text,
        ),
        const SettingsScreen(),
      ],
    );
  }

  // ── Selection helpers ─────────────────────────

  Set<String> _allSelectableSessionIds() {
    final sessions = ref.read(sessionsNotifierProvider);
    return sessions.values.map((s) => s.id).toSet();
  }

  bool _hasActiveSessionsInSelection(
    _SelectionState sel,
  ) {
    final sessions = ref.read(sessionsNotifierProvider);
    return sel.selectedIds.any((id) {
      final s = sessions[id];
      return s != null && isSessionActive(s);
    });
  }

  void _exitSelectionMode() {
    _selectionNotifier.value = const _SelectionState();
  }

  void _toggleSelectAll(
    Set<String> allIds,
    bool currentlyAllSelected,
  ) {
    final current = _selectionNotifier.value;
    _selectionNotifier.value = current.copyWith(
      selectedIds: currentlyAllSelected
          ? {}
          : Set<String>.of(allIds),
    );
  }

  Future<void> _confirmBatchArchive(
    BuildContext context,
    _SelectionState sel,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sessions = ref.read(sessionsNotifierProvider);
    final activeIds = sel.selectedIds
        .where((id) {
          final s = sessions[id];
          return s != null && isSessionActive(s);
        })
        .toList();
    if (activeIds.isEmpty) return;

    final count = activeIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl10n.sessionsArchiveSession),
          content: Text(
            dl10n.sessionsArchiveNConfirm(count),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl10n.sessionsArchive),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    _selectionNotifier.value =
        sel.copyWith(isBatchDeleting: true);

    var failCount = 0;
    for (final id in activeIds) {
      try {
        await SessionsApi().setSessionArchived(id, true);
        // Mark optimistically archived to prevent reappear during server lag.
        sync.markSessionArchived(id);
      } catch (e, st) {
        logger.error('Failed to archive session in batch: sessionId=$id', e, st);
        failCount++;
      }
    }

    if (mounted) {
      ref
          .read(sessionsNotifierProvider.notifier)
          .loadFromSync();
    }

    _exitSelectionMode();

    if (failCount > 0 && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.sessionsArchivePartialFail(failCount),
          ),
        ),
      );
    }
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    _SelectionState sel,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final count = sel.selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl10n.chatDeleteSession),
          content: Text(
            dl10n.sessionsDeleteNConfirm(count),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    _selectionNotifier.value =
        sel.copyWith(isBatchDeleting: true);

    final ids = List<String>.from(sel.selectedIds);

    // Optimistic: remove all immediately, restore failures.
    final failCount = await ref
        .read(sessionsNotifierProvider.notifier)
        .optimisticBatchDelete(ids);

    _exitSelectionMode();

    if (failCount > 0 && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.sessionsDeletePartialFail(failCount),
          ),
        ),
      );
    }
  }

  static Future<void> _showNewSessionDialog(
    BuildContext context,
  ) async {
    final sessionId = await showDialog<String>(
      context: context,
      builder: (context) => const NewSessionDialog(),
    );
    if (!context.mounted ||
        sessionId == null ||
        sessionId.isEmpty) {
      return;
    }
    unawaited(
      context.pushNamed(
        'chat',
        pathParameters: {'sessionId': sessionId},
      ),
    );
  }
}

// ─── Sorted session cache ─────────────────────────────────────────────────

/// Memoized result of sorting sessions into active and inactive lists.
class _SortedSessions {
  const _SortedSessions({
    required this.active,
    required this.inactive,
  });
  final List<Session> active;
  final List<Session> inactive;
}

/// Compute sorted active/inactive lists, only if [sessions] changed.
/// Sessions in [optimisticallyArchivedIds] are excluded from the active list
/// to prevent them from reappearing during server replication lag.
///
/// Sessions are sorted by last message timestamp when available,
/// falling back to [Session.activeAt] (active) or [Session.updatedAt]
/// (inactive).
_SortedSessions _computeSortedSessions(
  Map<String, Session> sessions, {
  required _SortedSessions? previous,
  required Map<String, Session>? lastSessions,
  required String? lastSearchQuery,
  required Set<String> optimisticallyArchivedIds,
  required int? Function(String sessionId)
      getLastMessageTimestamp,
  String searchQuery = '',
}) {
  if (previous != null &&
      identical(sessions, lastSessions) &&
      searchQuery == lastSearchQuery) {
    return previous;
  }

  final query = searchQuery.toLowerCase().trim();
  Iterable<Session> sessionList = sessions.values;
  if (query.isNotEmpty) {
    sessionList = sessionList.where((s) {
      final name = (s.metadata?.name ?? '').toLowerCase();
      final path = (s.metadata?.path ?? '').toLowerCase();
      final summary =
          (s.metadata?.summary?.text ?? '').toLowerCase();
      return name.contains(query) ||
          path.contains(query) ||
          summary.contains(query);
    });
  }

  final active = <Session>[];
  final inactive = <Session>[];
  for (final s in sessionList) {
    // Skip optimistically archived sessions from the active list.
    // They'll appear in inactive once the server confirms.
    if (optimisticallyArchivedIds.contains(s.id)) {
      continue;
    }
    if (isSessionActive(s)) {
      active.add(s);
    } else {
      inactive.add(s);
    }
  }
  active.sort((a, b) {
    // Currently-online sessions first within each directory group
    final aOnline = a.presence == 'online' ? 0 : 1;
    final bOnline = b.presence == 'online' ? 0 : 1;
    if (aOnline != bOnline) return aOnline.compareTo(bOnline);
    final aTs =
        getLastMessageTimestamp(a.id) ?? a.activeAt;
    final bTs =
        getLastMessageTimestamp(b.id) ?? b.activeAt;
    return bTs.compareTo(aTs);
  });
  inactive.sort((a, b) {
    final aTs =
        getLastMessageTimestamp(a.id) ?? a.updatedAt;
    final bTs =
        getLastMessageTimestamp(b.id) ?? b.updatedAt;
    return bTs.compareTo(aTs);
  });
  return _SortedSessions(active: active, inactive: inactive);
}

/// Sessions list content widget.
class _SessionsListContent extends ConsumerStatefulWidget {
  const _SessionsListContent({
    required this.selectionNotifier,
    this.searchQuery = '',
  });

  final ValueNotifier<_SelectionState> selectionNotifier;
  final String searchQuery;

  @override
  ConsumerState<_SessionsListContent> createState() =>
      _SessionsListContentState();
}

class _SessionsListContentState
    extends ConsumerState<_SessionsListContent> {
  bool _hasLoaded = false;
  bool _animationTriggered = false;
  final Set<String> _collapsedActivePaths = {};
  final Set<String> _collapsedFolderKeys = {};
  final Set<String> _collapsedDateKeys = {};
  ArchivedGrouping _archivedGrouping =
      ArchivedGrouping.date;
  _SortedSessions? _sortedCache;
  Map<String, Session>? _lastSessionsMap;
  String? _lastSearchQuery;

  ValueNotifier<_SelectionState> get _sel =>
      widget.selectionNotifier;

  @override
  void initState() {
    super.initState();
    _sel.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _sel.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _onSessionLongPress(String sessionId) {
    final current = _sel.value;
    if (!current.isActive) {
      HapticFeedback.mediumImpact();
      _sel.value = _SelectionState(
        isActive: true,
        selectedIds: {sessionId},
      );
    }
  }

  void _onSessionTapInSelectionMode(String sessionId) {
    final current = _sel.value;
    if (!current.isActive) return;
    final newIds = Set<String>.from(current.selectedIds);
    if (newIds.contains(sessionId)) {
      newIds.remove(sessionId);
    } else {
      newIds.add(sessionId);
    }
    if (newIds.isEmpty) {
      _sel.value = const _SelectionState();
    } else {
      _sel.value = current.copyWith(selectedIds: newIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsNotifierProvider);
    // Only watch the full machines map when folder-grouped view is
    // active. Machine heartbeats (activeAt updates) arrive every few
    // seconds and would otherwise trigger full session list rebuilds.
    final machines = _archivedGrouping == ArchivedGrouping.folder
        ? ref.watch(machinesNotifierProvider)
        : ref.read(machinesNotifierProvider);
    final hideInactive = ref.watch(
      settingsNotifierProvider
          .select((s) => s.hideInactiveSessions),
    );
    final showFlavorIcons = ref.watch(
      settingsNotifierProvider
          .select((s) => s.showFlavorIcons),
    );
    final avatarStyle = ref.watch(
      settingsNotifierProvider
          .select((s) => parseAvatarStyle(s.avatarStyle)),
    );

    final searchQuery = widget.searchQuery;

    // Get optimistically archived session IDs to filter from active list.
    final optimisticallyArchivedIds = sync.getOptimisticallyArchivedIds();

    final sorted = _computeSortedSessions(
      sessions,
      previous: _sortedCache,
      lastSessions: _lastSessionsMap,
      lastSearchQuery: _lastSearchQuery,
      optimisticallyArchivedIds: optimisticallyArchivedIds,
      getLastMessageTimestamp: sync.getLastMessageTimestamp,
      searchQuery: searchQuery,
    );
    _sortedCache = sorted;
    _lastSessionsMap = sessions;
    _lastSearchQuery = searchQuery;

    final activeSessions = sorted.active;
    final inactiveSessions = sorted.inactive;
    final sessionListCount =
        activeSessions.length + inactiveSessions.length;

    if (!_hasLoaded &&
        (sessionListCount > 0 || sync.isInitialized)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasLoaded = true);
      });
    }

    if (sessionListCount == 0 && !_hasLoaded) {
      return const SessionListShimmer();
    }

    if (sessionListCount == 0 && searchQuery.isNotEmpty) {
      return _buildSearchEmptyState(context);
    }

    if (sessionListCount == 0) {
      return const EmptySessionsView();
    }

    final triggerStagger = !_animationTriggered;
    if (!_animationTriggered) {
      _animationTriggered = true;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(sessionsNotifierProvider.notifier)
            .refreshFromSync();
      },
      color: Theme.of(context).colorScheme.primary,
      child: _buildSessionsList(
        context,
        activeSessions,
        inactiveSessions,
        machines,
        triggerStagger: triggerStagger,
        hideInactive: hideInactive,
        showFlavorIcons: showFlavorIcons,
        avatarStyle: avatarStyle,
      ),
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: cs.onSurfaceVariant
                .withValues(alpha: AppOpacity.medium),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.sessionsNoSearchResults,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  color: cs.onSurfaceVariant
                      .withValues(alpha: AppOpacity.half),
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: () {
              // Find the parent state to clear search
              final parent = context
                  .findAncestorStateOfType<
                      _SessionsScreenState>();
              if (parent != null && parent.mounted) {
                parent._searchController.clear();
                parent.setState(() {
                  parent._isSearching = false;
                });
              }
            },
            icon: const Icon(Icons.clear),
            label: Text(l10n.sessionsClearSearch),
          ),
        ],
      ),
    );
  }

  Key _keyForItem(_ListItem item) {
    return switch (item.type) {
      _ListItemType.activeSession ||
      _ListItemType.archivedSession ||
      _ListItemType.folderEntry =>
        ValueKey('s-${item.session!.id}'),
      _ListItemType.pathHeader =>
        ValueKey('p-${item.pathKey}'),
      _ListItemType.dateHeader =>
        ValueKey('d-${item.dateKey}'),
      _ListItemType.folderHeader =>
        ValueKey(
          'f-${item.folderHeader?.folderKey}',
        ),
      _ListItemType.sectionHeader =>
        ValueKey('sh-${item.title}'),
      _ListItemType.archiveHeader =>
        const ValueKey('archive-header'),
    };
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    Map<String, Machine> machines, {
    required bool triggerStagger,
    required bool hideInactive,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final activeByPath = <String, List<Session>>{};
    for (final s in activeSessions) {
      final path = s.metadata?.path ?? 'Unknown';
      activeByPath.putIfAbsent(path, () => []).add(s);
    }

    var staggerIndex = 0;
    final items = <_ListItem>[];

    if (activeSessions.isNotEmpty) {
      items.add(_ListItem.sectionHeader(
        context.l10n.sessionsActiveSessions,
        staggerIndex,
      ));

      for (final entry in (activeByPath.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)))) {
        final pathKey = entry.key;
        final isPathCollapsed =
            _collapsedActivePaths.contains(pathKey);
        items.add(_ListItem.pathHeader(
          pathKey,
          entry.value.length,
          isPathCollapsed,
          staggerIndex,
        ));
        if (!isPathCollapsed) {
          for (final session in entry.value) {
            items.add(_ListItem.activeSession(
              session,
              staggerIndex,
            ));
            staggerIndex++;
          }
        }
      }
    }

    if (shouldShowInactiveSessionsSection(
      hideInactive: hideInactive,
      activeCount: activeSessions.length,
      inactiveCount: inactiveSessions.length,
    )) {
      items.add(_ListItem.archiveHeader(
        inactiveSessions.length,
        _archivedGrouping,
        staggerIndex,
      ));

      final archivedItems =
          _archivedGrouping == ArchivedGrouping.folder
              ? _buildFolderGroupedItems(
                  inactiveSessions,
                  machines,
                  startIndex: staggerIndex,
                )
              : _buildDateGroupedItems(
                  inactiveSessions,
                  startIndex: staggerIndex,
                );
      items.addAll(archivedItems);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.lg,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final child = _buildItemWidget(
          context,
          item,
          showFlavorIcons: showFlavorIcons,
          avatarStyle: avatarStyle,
          triggerStagger: triggerStagger,
        );
        return StaggeredSlideIn(
          key: _keyForItem(item),
          index: item.staggerIndex,
          animate: triggerStagger,
          child: child,
        );
      },
    );
  }

  Widget _buildItemWidget(
    BuildContext context,
    _ListItem item, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    required bool triggerStagger,
  }) {
    final sel = _sel.value;

    switch (item.type) {
      case _ListItemType.sectionHeader:
        return FadeInSection(
          delay: Duration(
            milliseconds: kStaggerStep * item.staggerIndex,
          ),
          child: SectionHeader(title: item.title!),
        );

      case _ListItemType.pathHeader:
        final isPathCollapsed =
            _collapsedActivePaths.contains(item.pathKey!);
        return FadeInSection(
          delay: Duration(
            milliseconds: kStaggerStep * item.staggerIndex,
          ),
          child: PathHeader(
            path: item.pathKey!,
            sessionCount: item.sessionCount!,
            isCollapsed: isPathCollapsed,
            onToggle: () => setState(() {
              if (isPathCollapsed) {
                _collapsedActivePaths.remove(item.pathKey!);
              } else {
                _collapsedActivePaths.add(item.pathKey!);
              }
            }),
          ),
        );

      case _ListItemType.activeSession:
        final session = item.session!;
        final card = GestureDetector(
          onLongPress: () => _onSessionLongPress(session.id),
          child: CompactActiveSessionCard(
            session: session,
            onTap: sel.isActive
                ? () => _onSessionTapInSelectionMode(session.id)
                : () => unawaited(
                      context.pushNamed(
                        'chat',
                        pathParameters: {
                          'sessionId': session.id,
                        },
                      ),
                    ),
            showFlavorIcon: showFlavorIcons,
            avatarStyle: avatarStyle,
            lastMessageTimestamp:
                sync.getLastMessageTimestamp(session.id),
            lastMessagePreview:
                sync.getLastMessagePreview(session.id),
            isSelected: sel.selectedIds.contains(session.id),
            selectionMode: sel.isActive,
            unreadCount: sync.getUnreadCount(session.id),
          ),
        );
        return sel.isActive
            ? card
            : DismissibleActiveSession(
                session: session,
                child: card,
              );

      case _ListItemType.archiveHeader:
        return FadeInSection(
          delay: Duration(
            milliseconds: kStaggerStep * item.staggerIndex,
          ),
          child: ArchiveSectionHeader(
            count: item.sessionCount!,
            grouping: item.archivedGrouping!,
            onGroupingChanged: (g) =>
                setState(() => _archivedGrouping = g),
          ),
        );

      case _ListItemType.dateHeader:
        return FadeInSection(
          delay: Duration(
            milliseconds: kStaggerStep * item.staggerIndex,
          ),
          child: CollapsibleDateHeader(
            date: item.title!,
            sessionCount: item.sessionCount!,
            isCollapsed:
                _collapsedDateKeys.contains(item.dateKey!),
            onToggle: () => setState(() {
              if (_collapsedDateKeys.contains(item.dateKey!)) {
                _collapsedDateKeys.remove(item.dateKey!);
              } else {
                _collapsedDateKeys.add(item.dateKey!);
              }
            }),
          ),
        );

      case _ListItemType.archivedSession:
        final session = item.session!;
        final card = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SessionCard(
              session: session,
              onTap: sel.isActive
                  ? () => _onSessionTapInSelectionMode(session.id)
                  : () => unawaited(
                        context.pushNamed(
                          'chat',
                          pathParameters: {
                            'sessionId': session.id,
                          },
                        ),
                      ),
              onLongPress: () =>
                  _onSessionLongPress(session.id),
              isFirst: item.isFirst!,
              isLast: item.isLast!,
              isSingle: item.isSingle!,
              compact: true,
              selectionMode: sel.isActive,
              isSelected:
                  sel.selectedIds.contains(session.id),
              showFlavorIcon: showFlavorIcons,
              avatarStyle: avatarStyle,
              lastMessageTimestamp:
                  sync.getLastMessageTimestamp(session.id),
              lastMessagePreview:
                  sync.getLastMessagePreview(session.id),
            ),
            if (!item.isLast! && !item.isSingle!)
              Divider(
                height: 1,
                indent: 64,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: AppOpacity.soft),
              ),
          ],
        );
        return sel.isActive
            ? card
            : DismissibleInactiveSession(
                session: session,
                child: card,
              );

      case _ListItemType.folderHeader:
        return FadeInSection(
          delay: Duration(
            milliseconds: kStaggerStep * item.staggerIndex,
          ),
          child: CollapsibleFolderHeader(
            header: item.folderHeader!,
            isCollapsed: _collapsedFolderKeys
                .contains(item.folderHeader!.folderKey),
            onToggle: () => setState(() {
              final key = item.folderHeader!.folderKey;
              if (_collapsedFolderKeys.contains(key)) {
                _collapsedFolderKeys.remove(key);
              } else {
                _collapsedFolderKeys.add(key);
              }
            }),
          ),
        );

      case _ListItemType.folderEntry:
        final session = item.session!;
        final card = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SessionCard(
              session: session,
              onTap: sel.isActive
                  ? () => _onSessionTapInSelectionMode(session.id)
                  : () => unawaited(
                        context.pushNamed(
                          'chat',
                          pathParameters: {
                            'sessionId': session.id,
                          },
                        ),
                      ),
              onLongPress: () =>
                  _onSessionLongPress(session.id),
              isFirst: item.isFirst!,
              isLast: item.isLast!,
              isSingle: item.isSingle!,
              compact: true,
              selectionMode: sel.isActive,
              isSelected:
                  sel.selectedIds.contains(session.id),
              showFlavorIcon: showFlavorIcons,
              avatarStyle: avatarStyle,
              lastMessageTimestamp:
                  sync.getLastMessageTimestamp(session.id),
              lastMessagePreview:
                  sync.getLastMessagePreview(session.id),
            ),
            if (!item.isLast! && !item.isSingle!)
              Divider(
                height: 1,
                indent: 64,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: AppOpacity.soft),
              ),
          ],
        );
        return sel.isActive
            ? card
            : DismissibleInactiveSession(
                session: session,
                child: card,
              );
    }
  }

  List<_ListItem> _buildDateGroupedItems(
    List<Session> sessions, {
    required int startIndex,
  }) {
    final grouped =
        groupSessionsByDateCategory(
          sessions,
          getLastMessageTimestamp:
              sync.getLastMessageTimestamp,
        );

    var itemIndex = startIndex;
    final items = <_ListItem>[];

    for (final group in dateGroupOrder) {
      final dateSessions = grouped[group];
      if (dateSessions == null ||
          dateSessions.isEmpty) {
        continue;
      }

      final dateKey = group.name;
      final isCollapsed =
          _collapsedDateKeys.contains(dateKey);

      items.add(_ListItem.dateHeader(
        dateKey,
        _localizeDateGroup(group),
        dateSessions.length,
        itemIndex,
      ));

      if (!isCollapsed) {
        for (var i = 0;
            i < dateSessions.length;
            i++) {
          final session = dateSessions[i];
          final isFirst = i == 0;
          final isLast =
              i == dateSessions.length - 1;
          final isSingle =
              dateSessions.length == 1;

          items.add(_ListItem.archivedSession(
            session,
            itemIndex,
            isFirst: isFirst,
            isLast: isLast,
            isSingle: isSingle,
          ));
          itemIndex++;
        }
      }
    }

    return items;
  }

  String _localizeDateGroup(DateGroup g) {
    final l10n = context.l10n;
    return switch (g) {
      DateGroup.today => l10n.sessionsToday,
      DateGroup.yesterday => l10n.sessionsYesterday,
      DateGroup.thisWeek => l10n.sessionsThisWeek,
      DateGroup.thisMonth => l10n.sessionsThisMonth,
      DateGroup.older => l10n.sessionsOlder,
    };
  }

  List<_ListItem> _buildFolderGroupedItems(
    List<Session> sessions,
    Map<String, Machine> machines, {
    required int startIndex,
  }) {
    final folderItems =
        groupSessionsByFolder(
          sessions,
          machines,
          getLastMessageTimestamp:
              sync.getLastMessageTimestamp,
        );

    var itemIndex = startIndex;
    final items = <_ListItem>[];
    String? currentFolderKey;

    for (final item in folderItems) {
      switch (item) {
        case SessionFolderHeader():
          currentFolderKey = item.folderKey;
          items.add(_ListItem.folderHeader(
            item,
            itemIndex,
          ));
        case SessionFolderEntry():
          if (currentFolderKey != null &&
              _collapsedFolderKeys
                  .contains(currentFolderKey)) {
            continue;
          }
          final session = item.session;

          items.add(_ListItem.folderEntry(
            session,
            itemIndex,
            isFirst: item.isFirst,
            isLast: item.isLast,
            isSingle: item.isSingle,
          ));
          itemIndex++;
      }
    }

    return items;
  }
}

// ── List item descriptors ────────────────────────────────────────────────

enum _ListItemType {
  sectionHeader,
  pathHeader,
  activeSession,
  archiveHeader,
  dateHeader,
  archivedSession,
  folderHeader,
  folderEntry,
}

/// Lightweight descriptor for a list item. Widgets are built on demand
/// by [_SessionsListContentState._buildItemWidget].
class _ListItem {
  // Fields are non-nullable and populated by each named constructor.
  final _ListItemType type;
  final int staggerIndex;
  // Active/session items.
  final Session? session;
  final SessionFolderHeader? folderHeader;
  // Grouping metadata.
  final String? title;
  final String? pathKey;
  final int? sessionCount;
  final String? dateKey;
  final ArchivedGrouping? archivedGrouping;
  // Archived session card shapes.
  final bool? isFirst;
  final bool? isLast;
  final bool? isSingle;

  _ListItem._raw({
    required this.type,
    required this.staggerIndex,
    this.session,
    this.folderHeader,
    this.title,
    this.pathKey,
    this.sessionCount,
    this.dateKey,
    this.archivedGrouping,
    this.isFirst,
    this.isLast,
    this.isSingle,
  });

  _ListItem.sectionHeader(String title, int staggerIndex)
      : this._raw(
          type: _ListItemType.sectionHeader,
          staggerIndex: staggerIndex,
          title: title,
        );

  _ListItem.pathHeader(
    String pathKey,
    int sessionCount,
    bool _, // isCollapsed - unused at descriptor level
    int staggerIndex,
  ) : this._raw(
          type: _ListItemType.pathHeader,
          staggerIndex: staggerIndex,
          pathKey: pathKey,
          sessionCount: sessionCount,
        );

  _ListItem.activeSession(Session session, int staggerIndex)
      : this._raw(
          type: _ListItemType.activeSession,
          staggerIndex: staggerIndex,
          session: session,
        );

  _ListItem.archiveHeader(
    int sessionCount,
    ArchivedGrouping grouping,
    int staggerIndex,
  ) : this._raw(
          type: _ListItemType.archiveHeader,
          staggerIndex: staggerIndex,
          sessionCount: sessionCount,
          archivedGrouping: grouping,
        );

  _ListItem.dateHeader(
    String dateKey,
    String title,
    int sessionCount,
    int staggerIndex,
  ) : this._raw(
          type: _ListItemType.dateHeader,
          staggerIndex: staggerIndex,
          dateKey: dateKey,
          title: title,
          sessionCount: sessionCount,
        );

  _ListItem.archivedSession(
    Session session,
    int staggerIndex, {
    required bool isFirst,
    required bool isLast,
    required bool isSingle,
  }) : this._raw(
          type: _ListItemType.archivedSession,
          staggerIndex: staggerIndex,
          session: session,
          isFirst: isFirst,
          isLast: isLast,
          isSingle: isSingle,
        );

  _ListItem.folderHeader(
    SessionFolderHeader header,
    int staggerIndex,
  ) : this._raw(
          type: _ListItemType.folderHeader,
          staggerIndex: staggerIndex,
          folderHeader: header,
        );

  _ListItem.folderEntry(
    Session session,
    int staggerIndex, {
    required bool isFirst,
    required bool isLast,
    required bool isSingle,
  }) : this._raw(
          type: _ListItemType.folderEntry,
          staggerIndex: staggerIndex,
          session: session,
          isFirst: isFirst,
          isLast: isLast,
          isSingle: isSingle,
        );
}
