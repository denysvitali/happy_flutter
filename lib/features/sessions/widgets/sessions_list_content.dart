import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/auto_archive_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'empty_sessions_view.dart';
import 'folder_view_cards.dart';
import 'session_animations.dart';
import 'session_cards.dart';
import 'session_dismissible.dart';
import 'session_headers.dart';
import 'session_list_helpers.dart';
import 'session_shimmer.dart';

// ─── Main widget ──────────────────────────────────────

/// Sessions list content widget with date/folder grouping,
/// selection support, and staggered animations.
class SessionsListContent extends ConsumerStatefulWidget {
  const SessionsListContent({
    required this.selectionNotifier,
    required this.folderNotifier,
    this.searchQuery = '',
    this.onClearSearch,

    /// When provided, session taps call this instead of pushing a route.
    /// This allows a parent to handle navigation in a custom way
    /// (for example, tablet master-detail).
    this.onSessionTap,
    super.key,
  });

  final ValueNotifier<SelectionState> selectionNotifier;

  /// Notifies the parent when the user opens or closes a
  /// folder detail view. `null` means no folder is selected.
  final ValueNotifier<SessionFolderHeader?> folderNotifier;

  final String searchQuery;

  /// Called when the user taps "Clear search" in the
  /// empty-search state. The parent is responsible for
  /// clearing its search controller and exiting search
  /// mode.
  final VoidCallback? onClearSearch;

  /// Called when a session is tapped. Provides the session ID.
  /// When non-null, the list widget will call this instead of
  /// pushing the 'chat' route. Use this for custom navigation
  /// (e.g. master-detail layouts on tablet).
  final void Function(String sessionId)? onSessionTap;

  @override
  ConsumerState<SessionsListContent> createState() =>
      _SessionsListContentState();
}

class _SessionsListContentState extends ConsumerState<SessionsListContent> {
  bool _hasLoaded = false;
  bool _animationTriggered = false;
  String? _selectedFolderKey;
  final Set<String> _expandedArchivedFolders = {};
  final Set<String> _expandedOlderArchivedFolders = {};
  final Set<String> _collapsedActivePaths = {};
  final Set<String> _collapsedFolderKeys = {};
  final Set<String> _collapsedDateKeys = {};
  ArchivedGrouping _archivedGrouping = ArchivedGrouping.date;
  SortedSessions? _sortedCache;
  Map<String, Session>? _lastSessionsMap;
  String? _lastSearchQuery;
  List<ListItem>? _listItemsCache;
  int? _listItemsCacheSignature;

  /// Gate rapid taps on session cards.  Without this, 4 taps within
  /// ~50ms each call pushNamed('chat') and create 4 ChatScreen
  /// instances — which races their initState/build and causes
  /// "Null check operator used on a null value" crashes.
  int _lastNavTapMs = 0;
  static const _navDebounceMs = 400;

  ValueNotifier<SelectionState> get _sel => widget.selectionNotifier;

  void _navigateToChat(String sessionId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastNavTapMs < _navDebounceMs) return;
    _lastNavTapMs = nowMs;
    unawaited(
      context.pushNamed('chat', pathParameters: {'sessionId': sessionId}),
    );
  }

  @override
  void initState() {
    super.initState();
    _sel.addListener(_onSelectionChanged);
    widget.folderNotifier.addListener(_onFolderChanged);
  }

  @override
  void dispose() {
    _sel.removeListener(_onSelectionChanged);
    widget.folderNotifier.removeListener(_onFolderChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _onFolderChanged() {
    if (!mounted) return;
    final folder = widget.folderNotifier.value;
    if (folder == null && _selectedFolderKey != null) {
      _sel.value = const SelectionState();
      setState(() => _selectedFolderKey = null);
    }
  }

  void _openFolder(String folderKey, SessionFolderHeader header) {
    if (_sel.value.isActive) return;
    setState(() {
      _selectedFolderKey = folderKey;
      _expandedArchivedFolders.remove(folderKey);
      _expandedOlderArchivedFolders.remove(folderKey);
    });
    widget.folderNotifier.value = header;
  }

  void _closeFolder() {
    _sel.value = const SelectionState();
    setState(() => _selectedFolderKey = null);
    widget.folderNotifier.value = null;
  }

  void _toggleArchivedFolder(String folderKey) {
    setState(() {
      if (_expandedArchivedFolders.contains(folderKey)) {
        _expandedArchivedFolders.remove(folderKey);
        _expandedOlderArchivedFolders.remove(folderKey);
      } else {
        _expandedArchivedFolders.add(folderKey);
      }
    });
  }

  void _toggleOlderArchivedFolder(String folderKey) {
    setState(() {
      if (_expandedOlderArchivedFolders.contains(folderKey)) {
        _expandedOlderArchivedFolders.remove(folderKey);
      } else {
        _expandedOlderArchivedFolders.add(folderKey);
      }
    });
  }

  void _onSessionLongPress(String sessionId) {
    final current = _sel.value;
    if (!current.isActive) {
      HapticFeedback.mediumImpact();
      _sel.value = SelectionState(isActive: true, selectedIds: {sessionId});
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
      _sel.value = const SelectionState();
    } else {
      _sel.value = current.copyWith(selectedIds: newIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final machines = _archivedGrouping == ArchivedGrouping.folder
        ? ref.watch(machinesNotifierProvider)
        : ref.read(machinesNotifierProvider);
    final hideInactive = ref.watch(
      settingsNotifierProvider.select((s) => s.hideInactiveSessions),
    );
    final sessionsViewStyle = ref.watch(
      settingsNotifierProvider.select((s) => s.sessionsViewStyle),
    );
    final showFlavorIcons = ref.watch(
      settingsNotifierProvider.select((s) => s.showFlavorIcons),
    );
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select((s) => parseAvatarStyle(s.avatarStyle)),
    );

    final searchQuery = widget.searchQuery;
    final optimisticallyArchivedIds = sync.getOptimisticallyArchivedIds();

    final sorted = computeSortedSessions(
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
    final sessionListCount = activeSessions.length + inactiveSessions.length;

    if (!_hasLoaded && (sessionListCount > 0 || sync.isInitialized)) {
      _hasLoaded = true;
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
        await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      },
      color: Theme.of(context).colorScheme.primary,
      child: _buildSessionsList(
        context,
        activeSessions,
        inactiveSessions,
        machines,
        sessionsViewStyle: sessionsViewStyle,
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
            color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.medium),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.sessionsNoSearchResults,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.half),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: widget.onClearSearch,
            icon: const Icon(Icons.clear),
            label: Text(l10n.sessionsClearSearch),
          ),
        ],
      ),
    );
  }

  Key _keyForItem(ListItem item) {
    return switch (item.type) {
      ListItemType.activeSession ||
      ListItemType.archivedSession ||
      ListItemType.folderEntry => ValueKey('s-${item.session!.id}'),
      ListItemType.pathHeader => ValueKey('p-${item.pathKey}'),
      ListItemType.dateHeader => ValueKey('d-${item.dateKey}'),
      ListItemType.folderHeader => ValueKey(
        'f-${item.folderHeader?.folderKey}',
      ),
      ListItemType.folderSectionHeader => ValueKey(
        'fs-${item.title}-${item.staggerIndex}',
      ),
      ListItemType.sectionHeader => ValueKey('sh-${item.title}'),
      ListItemType.archiveHeader => const ValueKey('archive-header'),
    };
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    Map<String, Machine> machines, {
    required String sessionsViewStyle,
    required bool triggerStagger,
    required bool hideInactive,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    if (sessionsViewStyle == 'folder') {
      return _buildFolderModeView(
        context,
        activeSessions,
        inactiveSessions,
        machines,
        triggerStagger: triggerStagger,
        showFlavorIcons: showFlavorIcons,
        avatarStyle: avatarStyle,
      );
    }

    if (sessionsViewStyle == 'unread_focus') {
      return _buildUnreadFocusView(
        context,
        activeSessions,
        inactiveSessions,
        triggerStagger: triggerStagger,
        showFlavorIcons: showFlavorIcons,
        avatarStyle: avatarStyle,
      );
    }

    final items = _buildListItems(
      context,
      activeSessions,
      inactiveSessions,
      machines,
      sessionsViewStyle: sessionsViewStyle,
      hideInactive: hideInactive,
    );

    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      // Session cards use RepaintBoundary via StaggeredSlideIn;
      // disable the default keep-alive and repaint wrappers to
      // avoid double-wrapping overhead on large lists.
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
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

  bool _sessionNeedsAttention(String sessionId, Session session) {
    if (sync.getUnreadCount(sessionId) > 0) return true;
    final status = getSessionStatus(session);
    return status.isPulsing;
  }

  Widget _buildUnreadFocusView(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions, {
    required bool triggerStagger,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    // Partition active sessions into Needs Attention vs All Others.
    final needsAttention = <Session>[];
    final allOthers = <Session>[];
    for (final session in activeSessions) {
      if (_sessionNeedsAttention(session.id, session)) {
        needsAttention.add(session);
      } else {
        allOthers.add(session);
      }
    }

    // Build the item list: Needs Attention header + cards, then All header
    // + cards.
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary.toARGB32();
    final items = <Widget>[];

    if (needsAttention.isNotEmpty) {
      items.add(
        SectionHeader(
          title: l10n.sessionsNeedsAttention,
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '${needsAttention.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < needsAttention.length; i++) {
        final session = needsAttention[i];
        items.add(
          _buildUnreadFocusCard(
            context,
            session,
            accentBarColor: primaryColor,
            showFlavorIcons: showFlavorIcons,
            avatarStyle: avatarStyle,
            needsAttention: true,
            triggerStagger: triggerStagger,
            staggerIndex: i,
          ),
        );
      }

      items.add(const SizedBox(height: AppSpacing.sm));
    }

    // All Sessions section.
    final allStartIndex = needsAttention.length;
    items.add(SectionHeader(title: l10n.sessionsAllSessions));

    for (var i = 0; i < allOthers.length; i++) {
      final session = allOthers[i];
      items.add(
        _buildUnreadFocusCard(
          context,
          session,
          showFlavorIcons: showFlavorIcons,
          avatarStyle: avatarStyle,
          needsAttention: false,
          triggerStagger: triggerStagger,
          staggerIndex: allStartIndex + i,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: items.length,
      itemBuilder: (ctx, i) => items[i],
    );
  }

  Widget _buildUnreadFocusCard(
    BuildContext context,
    Session session, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    required bool needsAttention,
    required bool triggerStagger,
    required int staggerIndex,
    int? accentBarColor,
  }) {
    final sel = _sel.value;
    final card = GestureDetector(
      onLongPress: () => _onSessionLongPress(session.id),
      child: CompactActiveSessionCard(
        session: session,
        onTap: sel.isActive
            ? () => _onSessionTapInSelectionMode(session.id)
            : () => _navigateToChat(session.id),
        showFlavorIcon: showFlavorIcons,
        avatarStyle: avatarStyle,
        lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
        lastMessagePreview: sync.getLastMessagePreview(session.id),
        lastMessageRole: sync.getLastMessageRole(session.id),
        isSelected: sel.selectedIds.contains(session.id),
        selectionMode: sel.isActive,
        unreadCount: sync.getUnreadCount(session.id),
        accentBarColor: accentBarColor,
        archiveCountdownLabel: null,
      ),
    );
    return sel.isActive
        ? card
        : DismissibleActiveSession(session: session, child: card);
  }

  Widget _buildFolderModeView(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    Map<String, Machine> machines, {
    required bool triggerStagger,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final folders = groupAllSessionsByFolder(
      activeSessions,
      inactiveSessions,
      machines,
      getLastMessageTimestamp: sync.getLastMessageTimestamp,
      getUnreadCount: sync.getUnreadCount,
    );

    SessionFolderGroup? selectedFolder;
    if (_selectedFolderKey != null) {
      for (final folder in folders) {
        if (folder.header.folderKey == _selectedFolderKey) {
          selectedFolder = folder;
          break;
        }
      }
    }

    if (_selectedFolderKey != null && selectedFolder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedFolderKey = null);
          widget.folderNotifier.value = null;
        }
      });
    }

    if (selectedFolder == null) {
      return ListView.builder(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.lg,
        ),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        itemCount: folders.length,
        itemBuilder: (ctx, i) {
          final folder = folders[i];
          final child = FolderOverviewCard(
            header: folder.header,
            onTap: () => _openFolder(folder.header.folderKey, folder.header),
          );
          return StaggeredSlideIn(
            key: ValueKey('folder-${folder.header.folderKey}'),
            index: i,
            animate: triggerStagger,
            child: child,
          );
        },
      );
    }

    final folder = selectedFolder;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final recentArchived = <Session>[];
    final olderArchived = <Session>[];
    for (final session in folder.inactiveSessions) {
      final activityAt =
          sync.getLastMessageTimestamp(session.id) ?? session.updatedAt;
      if (activityAt >= sevenDaysAgo) {
        recentArchived.add(session);
      } else {
        olderArchived.add(session);
      }
    }
    final isArchivedExpanded = _expandedArchivedFolders.contains(
      folder.header.folderKey,
    );
    final isOlderArchivedExpanded = _expandedOlderArchivedFolders.contains(
      folder.header.folderKey,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeFolder();
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.lg,
        ),
        children: [
          if (folder.activeSessions.isNotEmpty)
            FolderSectionHeader(
              title: context.l10n.sessionsActiveSessions,
              count: folder.activeSessions.length,
            ),
          if (folder.activeSessions.isNotEmpty)
            _buildFolderSessionGroup(
              folder.activeSessions,
              showFlavorIcons: showFlavorIcons,
              avatarStyle: avatarStyle,
            ),
          if (folder.inactiveSessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: TextButton.icon(
                onPressed: () => _toggleArchivedFolder(folder.header.folderKey),
                icon: Icon(
                  isArchivedExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  isArchivedExpanded
                      ? context.l10n.sessionsHideArchived
                      : context.l10n.sessionsShowArchived(
                          folder.inactiveSessions.length,
                        ),
                ),
              ),
            ),
          if (isArchivedExpanded) ...[
            if (recentArchived.isNotEmpty)
              FolderSectionHeader(
                title: context.l10n.sessionsArchivedLabel,
                count: recentArchived.length,
              ),
            if (recentArchived.isNotEmpty)
              _buildFolderSessionGroup(
                recentArchived,
                showFlavorIcons: showFlavorIcons,
                avatarStyle: avatarStyle,
                archived: true,
              ),
            if (olderArchived.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: TextButton(
                  onPressed: () =>
                      _toggleOlderArchivedFolder(folder.header.folderKey),
                  child: Text(
                    isOlderArchivedExpanded
                        ? context.l10n.sessionsHideOlderArchived
                        : context.l10n.sessionsShowOlderArchived(
                            olderArchived.length,
                          ),
                  ),
                ),
              ),
            if (olderArchived.isNotEmpty && isOlderArchivedExpanded)
              _buildFolderSessionGroup(
                olderArchived,
                showFlavorIcons: showFlavorIcons,
                avatarStyle: avatarStyle,
                archived: true,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderSessionGroup(
    List<Session> sessions, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    bool archived = false,
  }) {
    final rows = <Widget>[];
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      final row = _buildFolderSessionRow(
        session,
        showFlavorIcons: showFlavorIcons,
        avatarStyle: avatarStyle,
        archived: archived,
      );
      rows.add(row);
    }
    return FolderSessionGroup(children: rows);
  }

  Widget _buildFolderSessionRow(
    Session session, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    required bool archived,
  }) {
    final sel = _sel.value;

    void handleTap() {
      final cb = widget.onSessionTap;
      if (cb != null) {
        cb(session.id);
      } else if (sel.isActive) {
        _onSessionTapInSelectionMode(session.id);
      } else {
        _navigateToChat(session.id);
      }
    }

    final row = FolderSessionRow(
      session: session,
      onTap: handleTap,
      onLongPress: () => _onSessionLongPress(session.id),
      showFlavorIcon: showFlavorIcons,
      avatarStyle: avatarStyle,
      lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
      lastMessagePreview: sync.getLastMessagePreview(session.id),
      lastMessageRole: sync.getLastMessageRole(session.id),
      isSelected: sel.selectedIds.contains(session.id),
      selectionMode: sel.isActive,
      unreadCount: archived ? 0 : sync.getUnreadCount(session.id),
      archiveCountdownLabel: archived ? _archiveCountdownLabel(session) : null,
      muted: archived,
    );

    if (sel.isActive) return row;
    return archived
        ? DismissibleInactiveSession(session: session, child: row)
        : DismissibleActiveSession(session: session, child: row);
  }

  List<ListItem> _buildListItems(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    Map<String, Machine> machines, {
    required String sessionsViewStyle,
    required bool hideInactive,
  }) {
    final signature = Object.hashAll(<Object?>[
      sessionsViewStyle,
      activeSessions.length,
      inactiveSessions.length,
      for (final session in activeSessions) session.id,
      for (final session in inactiveSessions) session.id,
      hideInactive,
      _archivedGrouping,
      Object.hashAllUnordered(_collapsedActivePaths),
      Object.hashAllUnordered(_collapsedFolderKeys),
      Object.hashAllUnordered(_collapsedDateKeys),
      if (sessionsViewStyle == 'folder' ||
          _archivedGrouping == ArchivedGrouping.folder)
        for (final entry in machines.entries)
          Object.hash(
            entry.key,
            entry.value.metadata?.displayName,
            entry.value.metadata?.host,
          ),
    ]);

    final cachedItems = _listItemsCache;
    if (cachedItems != null && _listItemsCacheSignature == signature) {
      return cachedItems;
    }

    final activeByPath = <String, List<Session>>{};
    for (final s in activeSessions) {
      final path = s.metadata?.path ?? 'Unknown';
      activeByPath.putIfAbsent(path, () => []).add(s);
    }

    var staggerIndex = 0;
    final items = <ListItem>[];

    if (activeSessions.isNotEmpty) {
      items.add(
        ListItem.sectionHeader(
          context.l10n.sessionsActiveSessions,
          staggerIndex,
        ),
      );

      for (final entry
          in (activeByPath.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))) {
        final pathKey = entry.key;
        final isPathCollapsed = _collapsedActivePaths.contains(pathKey);
        items.add(
          ListItem.pathHeader(
            pathKey,
            entry.value.length,
            isPathCollapsed,
            staggerIndex,
          ),
        );
        if (!isPathCollapsed) {
          for (final session in entry.value) {
            items.add(ListItem.activeSession(session, staggerIndex));
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
      items.add(
        ListItem.archiveHeader(
          inactiveSessions.length,
          _archivedGrouping,
          staggerIndex,
        ),
      );

      final archivedItems = _archivedGrouping == ArchivedGrouping.folder
          ? _buildFolderGroupedItems(
              inactiveSessions,
              machines,
              startIndex: staggerIndex,
            )
          : _buildDateGroupedItems(inactiveSessions, startIndex: staggerIndex);
      items.addAll(archivedItems);
    }

    _listItemsCacheSignature = signature;
    _listItemsCache = List<ListItem>.unmodifiable(items);
    return _listItemsCache!;
  }

  /// Builds a card for archived or folder-grouped sessions.
  /// Both [archivedSession] and [folderEntry] use the same
  /// layout (SessionCard + optional divider + dismissible).
  Widget _buildArchivedCard(
    BuildContext context,
    ListItem item, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final sel = _sel.value;
    final session = item.session!;

    void handleTap() {
      final cb = widget.onSessionTap;
      if (cb != null) {
        cb(session.id);
      } else if (sel.isActive) {
        _onSessionTapInSelectionMode(session.id);
      } else {
        _navigateToChat(session.id);
      }
    }

    final card = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionCard(
          session: session,
          onTap: handleTap,
          onLongPress: () => _onSessionLongPress(session.id),
          isFirst: item.isFirst!,
          isLast: item.isLast!,
          isSingle: item.isSingle!,
          compact: true,
          selectionMode: sel.isActive,
          isSelected: sel.selectedIds.contains(session.id),
          showFlavorIcon: showFlavorIcons,
          avatarStyle: avatarStyle,
          lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
          lastMessagePreview: sync.getLastMessagePreview(session.id),
          lastMessageRole: sync.getLastMessageRole(session.id),
          archiveCountdownLabel: _archiveCountdownLabel(session),
        ),
        if (!item.isLast! && !item.isSingle!)
          Divider(
            height: 1,
            indent: 64,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: AppOpacity.soft),
          ),
      ],
    );
    return sel.isActive
        ? card
        : DismissibleInactiveSession(session: session, child: card);
  }

  Widget _buildItemWidget(
    BuildContext context,
    ListItem item, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    required bool triggerStagger,
  }) {
    switch (item.type) {
      case ListItemType.sectionHeader:
        // StaggeredSlideIn already wraps every item with a staggered
        // fade+slide — no need for a second FadeInSection controller.
        return SectionHeader(title: item.title!);

      case ListItemType.pathHeader:
        final isPathCollapsed = _collapsedActivePaths.contains(item.pathKey!);
        return PathHeader(
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
        );

      case ListItemType.activeSession:
        final session = item.session!;
        return _buildActiveSessionCard(
          session,
          showFlavorIcons: showFlavorIcons,
          avatarStyle: avatarStyle,
        );

      case ListItemType.archiveHeader:
        return ArchiveSectionHeader(
          count: item.sessionCount!,
          grouping: item.archivedGrouping!,
          onGroupingChanged: (g) => setState(() => _archivedGrouping = g),
        );

      case ListItemType.folderSectionHeader:
        return FolderSectionHeader(
          title: item.title!,
          count: item.sessionCount!,
        );

      case ListItemType.dateHeader:
        return CollapsibleDateHeader(
          date: item.title!,
          sessionCount: item.sessionCount!,
          isCollapsed: _collapsedDateKeys.contains(item.dateKey!),
          onToggle: () => setState(() {
            if (_collapsedDateKeys.contains(item.dateKey!)) {
              _collapsedDateKeys.remove(item.dateKey!);
            } else {
              _collapsedDateKeys.add(item.dateKey!);
            }
          }),
        );

      case ListItemType.archivedSession:
      case ListItemType.folderEntry:
        return _buildArchivedCard(
          context,
          item,
          showFlavorIcons: showFlavorIcons,
          avatarStyle: avatarStyle,
        );

      case ListItemType.folderHeader:
        return CollapsibleFolderHeader(
          header: item.folderHeader!,
          isCollapsed: _collapsedFolderKeys.contains(
            item.folderHeader!.folderKey,
          ),
          onToggle: () => setState(() {
            final key = item.folderHeader!.folderKey;
            if (_collapsedFolderKeys.contains(key)) {
              _collapsedFolderKeys.remove(key);
            } else {
              _collapsedFolderKeys.add(key);
            }
          }),
        );
    }
  }

  Widget _buildActiveSessionCard(
    Session session, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final sel = _sel.value;
    void handleTap() {
      final cb = widget.onSessionTap;
      if (cb != null) {
        cb(session.id);
      } else if (sel.isActive) {
        _onSessionTapInSelectionMode(session.id);
      } else {
        _navigateToChat(session.id);
      }
    }

    final card = GestureDetector(
      onLongPress: () => _onSessionLongPress(session.id),
      child: CompactActiveSessionCard(
        session: session,
        onTap: handleTap,
        showFlavorIcon: showFlavorIcons,
        avatarStyle: avatarStyle,
        lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
        lastMessagePreview: sync.getLastMessagePreview(session.id),
        lastMessageRole: sync.getLastMessageRole(session.id),
        isSelected: sel.selectedIds.contains(session.id),
        selectionMode: sel.isActive,
        unreadCount: sync.getUnreadCount(session.id),
        archiveCountdownLabel: null,
      ),
    );
    return sel.isActive
        ? card
        : DismissibleActiveSession(session: session, child: card);
  }

  String? _archiveCountdownLabel(Session session) {
    final settings = AutoArchiveService.instance.getSettings();
    final duration = AutoArchiveService.idleArchiveDuration(settings);
    if (duration == null) return null;
    if (session.presence == 'online' || session.thinking) return null;
    if (session.pinned || AutoArchiveService.hasPendingPermission(session)) {
      return null;
    }
    if (session.draft != null && session.draft!.isNotEmpty) return null;
    if (AutoArchiveService.hasUnsettledSend(
      sync.messagesForSession(session.id),
    )) {
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final archiveAt = session.updatedAt + duration.inMilliseconds;
    final remaining = Duration(milliseconds: archiveAt - now);
    if (remaining <= Duration.zero) return 'Archiving soon';
    if (remaining.inMinutes < 1) return 'Archives <1m';
    if (remaining.inHours < 1) {
      return 'Archives ${remaining.inMinutes}m';
    }
    if (remaining.inHours < 24) {
      final minutes = remaining.inMinutes.remainder(60);
      if (minutes == 0) return 'Archives ${remaining.inHours}h';
      return 'Archives ${remaining.inHours}h ${minutes}m';
    }
    return 'Archives ${remaining.inDays}d';
  }

  List<ListItem> _buildDateGroupedItems(
    List<Session> sessions, {
    required int startIndex,
  }) {
    final grouped = groupSessionsByDateCategory(
      sessions,
      getLastMessageTimestamp: sync.getLastMessageTimestamp,
    );

    var itemIndex = startIndex;
    final items = <ListItem>[];

    for (final group in dateGroupOrder) {
      final dateSessions = grouped[group];
      if (dateSessions == null || dateSessions.isEmpty) {
        continue;
      }

      final dateKey = group.name;
      final isCollapsed = _collapsedDateKeys.contains(dateKey);

      items.add(
        ListItem.dateHeader(
          dateKey,
          _localizeDateGroup(group),
          dateSessions.length,
          itemIndex,
        ),
      );

      if (!isCollapsed) {
        for (var i = 0; i < dateSessions.length; i++) {
          final session = dateSessions[i];
          final isFirst = i == 0;
          final isLast = i == dateSessions.length - 1;
          final isSingle = dateSessions.length == 1;

          items.add(
            ListItem.archivedSession(
              session,
              itemIndex,
              isFirst: isFirst,
              isLast: isLast,
              isSingle: isSingle,
            ),
          );
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

  List<ListItem> _buildFolderGroupedItems(
    List<Session> sessions,
    Map<String, Machine> machines, {
    required int startIndex,
  }) {
    final folderItems = groupSessionsByFolder(
      sessions,
      machines,
      getLastMessageTimestamp: sync.getLastMessageTimestamp,
    );

    var itemIndex = startIndex;
    final items = <ListItem>[];
    String? currentFolderKey;

    for (final item in folderItems) {
      switch (item) {
        case SessionFolderHeader():
          currentFolderKey = item.folderKey;
          items.add(ListItem.folderHeader(item, itemIndex));
        case SessionFolderEntry():
          if (currentFolderKey != null &&
              _collapsedFolderKeys.contains(currentFolderKey)) {
            continue;
          }
          final session = item.session;

          items.add(
            ListItem.folderEntry(
              session,
              itemIndex,
              isFirst: item.isFirst,
              isLast: item.isLast,
              isSingle: item.isSingle,
            ),
          );
          itemIndex++;
      }
    }

    return items;
  }
}
