import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'empty_sessions_view.dart';
import 'session_animations.dart';
import 'session_cards.dart';
import 'session_dismissible.dart';
import 'session_headers.dart';
import 'session_shimmer.dart';

// ─── Selection state ──────────────────────────────────

/// Immutable selection state shared between the parent
/// screen (AppBar) and the list content via a
/// [ValueNotifier].
class SelectionState {
  const SelectionState({
    this.isActive = false,
    this.selectedIds = const {},
    this.isBatchDeleting = false,
  });

  final bool isActive;
  final Set<String> selectedIds;
  final bool isBatchDeleting;

  SelectionState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
    bool? isBatchDeleting,
  }) {
    return SelectionState(
      isActive: isActive ?? this.isActive,
      selectedIds: selectedIds ?? this.selectedIds,
      isBatchDeleting:
          isBatchDeleting ?? this.isBatchDeleting,
    );
  }
}

// ─── Sorted session cache ─────────────────────────────

/// Memoized result of sorting sessions into active and
/// inactive lists.
class _SortedSessions {
  const _SortedSessions({
    required this.active,
    required this.inactive,
  });
  final List<Session> active;
  final List<Session> inactive;
}

/// Compute sorted active/inactive lists, only if
/// [sessions] changed.
///
/// Sessions in [optimisticallyArchivedIds] are excluded
/// from the active list to prevent them from reappearing
/// during server replication lag.
///
/// Sessions are sorted by last message timestamp when
/// available, falling back to [Session.activeAt] (active)
/// or [Session.updatedAt] (inactive).
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
  var sessionList = sessions.values;
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

// ── List item descriptors ─────────────────────────────

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

/// Lightweight descriptor for a list item. Widgets are
/// built on demand by
/// [_SessionsListContentState._buildItemWidget].
class _ListItem {
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

  _ListItem.activeSession(
      Session session, int staggerIndex)
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

  final _ListItemType type;
  final int staggerIndex;
  final Session? session;
  final SessionFolderHeader? folderHeader;
  final String? title;
  final String? pathKey;
  final int? sessionCount;
  final String? dateKey;
  final ArchivedGrouping? archivedGrouping;
  final bool? isFirst;
  final bool? isLast;
  final bool? isSingle;
}

// ─── Main widget ──────────────────────────────────────

/// Whether to show the inactive/archived sessions section.
bool shouldShowInactiveSessionsSection({
  required bool hideInactive,
  required int activeCount,
  required int inactiveCount,
}) {
  if (inactiveCount == 0) return false;
  if (!hideInactive) return true;
  return activeCount == 0;
}

/// Sessions list content widget with date/folder grouping,
/// selection support, and staggered animations.
class SessionsListContent extends ConsumerStatefulWidget {
  const SessionsListContent({
    required this.selectionNotifier,
    this.searchQuery = '',
    this.onClearSearch,
    super.key,
  });

  final ValueNotifier<SelectionState> selectionNotifier;
  final String searchQuery;

  /// Called when the user taps "Clear search" in the
  /// empty-search state. The parent is responsible for
  /// clearing its search controller and exiting search
  /// mode.
  final VoidCallback? onClearSearch;

  @override
  ConsumerState<SessionsListContent> createState() =>
      _SessionsListContentState();
}

class _SessionsListContentState
    extends ConsumerState<SessionsListContent> {
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

  ValueNotifier<SelectionState> get _sel =>
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
      _sel.value = SelectionState(
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
      _sel.value = const SelectionState();
    } else {
      _sel.value = current.copyWith(selectedIds: newIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final machines = _archivedGrouping ==
            ArchivedGrouping.folder
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
    final optimisticallyArchivedIds =
        sync.getOptimisticallyArchivedIds();

    final sorted = _computeSortedSessions(
      sessions,
      previous: _sortedCache,
      lastSessions: _lastSessionsMap,
      lastSearchQuery: _lastSearchQuery,
      optimisticallyArchivedIds:
          optimisticallyArchivedIds,
      getLastMessageTimestamp:
          sync.getLastMessageTimestamp,
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

    if (sessionListCount == 0 &&
        searchQuery.isNotEmpty) {
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
            onPressed: widget.onClearSearch,
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

  /// Builds a card for archived or folder-grouped sessions.
  /// Both [archivedSession] and [folderEntry] use the same
  /// layout (SessionCard + optional divider + dismissible).
  Widget _buildArchivedCard(
    BuildContext context,
    _ListItem item, {
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final sel = _sel.value;
    final session = item.session!;
    final card = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionCard(
          session: session,
          onTap: sel.isActive
              ? () => _onSessionTapInSelectionMode(
                  session.id)
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
          lastMessageRole:
              sync.getLastMessageRole(session.id),
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
            milliseconds:
                kStaggerStep * item.staggerIndex,
          ),
          child: SectionHeader(title: item.title!),
        );

      case _ListItemType.pathHeader:
        final isPathCollapsed =
            _collapsedActivePaths.contains(item.pathKey!);
        return FadeInSection(
          delay: Duration(
            milliseconds:
                kStaggerStep * item.staggerIndex,
          ),
          child: PathHeader(
            path: item.pathKey!,
            sessionCount: item.sessionCount!,
            isCollapsed: isPathCollapsed,
            onToggle: () => setState(() {
              if (isPathCollapsed) {
                _collapsedActivePaths
                    .remove(item.pathKey!);
              } else {
                _collapsedActivePaths.add(item.pathKey!);
              }
            }),
          ),
        );

      case _ListItemType.activeSession:
        final session = item.session!;
        final card = GestureDetector(
          onLongPress: () =>
              _onSessionLongPress(session.id),
          child: CompactActiveSessionCard(
            session: session,
            onTap: sel.isActive
                ? () => _onSessionTapInSelectionMode(
                    session.id)
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
            lastMessageRole:
                sync.getLastMessageRole(session.id),
            isSelected:
                sel.selectedIds.contains(session.id),
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
            milliseconds:
                kStaggerStep * item.staggerIndex,
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
            milliseconds:
                kStaggerStep * item.staggerIndex,
          ),
          child: CollapsibleDateHeader(
            date: item.title!,
            sessionCount: item.sessionCount!,
            isCollapsed:
                _collapsedDateKeys.contains(item.dateKey!),
            onToggle: () => setState(() {
              if (_collapsedDateKeys
                  .contains(item.dateKey!)) {
                _collapsedDateKeys.remove(item.dateKey!);
              } else {
                _collapsedDateKeys.add(item.dateKey!);
              }
            }),
          ),
        );

      case _ListItemType.archivedSession:
      case _ListItemType.folderEntry:
        return _buildArchivedCard(
          context,
          item,
          showFlavorIcons: showFlavorIcons,
          avatarStyle: avatarStyle,
        );

      case _ListItemType.folderHeader:
        return FadeInSection(
          delay: Duration(
            milliseconds:
                kStaggerStep * item.staggerIndex,
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
