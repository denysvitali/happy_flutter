import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../core/components/app_status_dot.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_status.dart';
import '../../core/utils/session_utils.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import 'session_avatar.dart';

// ─── Stagger constants ───────────────────────────────────────────────────────
const _kStaggerStep = 30; // ms between each card
const _kSlideDuration = 250; // ms for slide+fade

// ─── Selection state ──────────────────────────────────────────────────────────

/// How to group archived sessions.
enum _ArchivedGrouping { date, folder }

/// Immutable selection state shared between the parent screen
/// (AppBar) and the list content via a [ValueNotifier].
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

/// Sessions list screen with date grouping and enhanced status display.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late AppTab _activeTab;
  StreamSubscription<void>? _syncSubscription;
  final _selectionNotifier = ValueNotifier<_SelectionState>(
    const _SelectionState(),
  );

  @override
  void initState() {
    super.initState();
    _activeTab = _parseTab(widget.initialTab);
    _selectionNotifier.addListener(_onSelectionChanged);
    Future<void>.microtask(() async {
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      await ref.read(friendsNotifierProvider.notifier).refreshFromSync();
      await ref.read(feedNotifierProvider.notifier).refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
      ref.read(friendsNotifierProvider.notifier).loadFromSync();
      ref.read(feedNotifierProvider.notifier).loadFromSync();
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
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
    final currentUri = router.routeInformationProvider.value.uri;

    // Only update if we're on the sessions route
    if (currentUri.path == '/sessions') {
      final newTab = _tabToString(tab);
      final newUri = currentUri.replace(
        queryParameters: newTab == 'sessions' ? {} : {'tab': newTab},
      );

      // Use replace to avoid adding to history stack for tab switches
      router.replace(newUri.toString());
    }
  }

  @override
  void dispose() {
    _selectionNotifier.removeListener(_onSelectionChanged);
    _selectionNotifier.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inboxBadgeCount = ref.watch(
      friendsNotifierProvider.select((s) => s.incomingRequests.length),
    );
    final showInboxDot = ref.watch(
      feedNotifierProvider.select((s) => s.unreadCount > 0),
    );

    return PopScope(
      canPop: _activeTab == AppTab.sessions,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _activeTab != AppTab.sessions) {
          setState(() => _activeTab = AppTab.sessions);
          _updateUrlTab(AppTab.sessions);
        } else if (!didPop && _activeTab == AppTab.sessions) {
          final now = DateTime.now();
          if (_lastBackPressTime == null ||
              now.difference(_lastBackPressTime!) >
                  const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Press back again to exit'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context, l10n),
        body: _buildCurrentTabContent(),
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
    return AppBar(
      title: Text(l10n.sessionHistoryTitle),
      actions: [
        ConnectionStatusBadge(status: connectionStatus),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () =>
              _SessionsListContent.showNewSessionDialog(
                context,
              ),
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
    final allIds = _allInactiveSessionIds();
    final allSelected = allIds.isNotEmpty &&
        allIds.every(sel.selectedIds.contains);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
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
              : () => _toggleSelectAll(
                    allIds,
                    allSelected,
                  ),
          child: Text(
            allSelected
                ? l10n.sessionsDeselectAll
                : l10n.sessionsSelectAll,
          ),
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
        ),
        const SettingsScreen(),
      ],
    );
  }

  // ── Selection helpers ───────────────────────────────────

  Set<String> _allInactiveSessionIds() {
    final sessions = ref.read(sessionsNotifierProvider);
    return sessions.values
        .where((s) => !isSessionActive(s))
        .map((s) => s.id)
        .toSet();
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
      selectedIds:
          currentlyAllSelected ? {} : Set<String>.of(allIds),
    );
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    _SelectionState sel,
  ) async {
    final l10n = context.l10n;
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
    final results = await Future.wait(
      ids.map(sync.deleteSession),
    );

    if (mounted) {
      await ref
          .read(sessionsNotifierProvider.notifier)
          .refreshFromSync();
    }

    _exitSelectionMode();

    final failCount = results.where((r) => !r).length;
    if (failCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.sessionsDeletePartialFail(failCount),
          ),
        ),
      );
    }
  }
}

/// Sessions list content widget.
class _SessionsListContent extends ConsumerStatefulWidget {
  const _SessionsListContent({
    required this.selectionNotifier,
  });

  final ValueNotifier<_SelectionState> selectionNotifier;

  static void showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NewSessionDialog(),
    );
  }

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
  _ArchivedGrouping _archivedGrouping =
      _ArchivedGrouping.date;

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
    final machines = ref.watch(machinesNotifierProvider);
    // Only watch the specific settings fields that affect session display to
    // avoid re-sorting on every unrelated settings change.
    final hideInactive = ref.watch(
      settingsNotifierProvider.select((s) => s.hideInactiveSessions),
    );
    final showFlavorIcons = ref.watch(
      settingsNotifierProvider.select((s) => s.showFlavorIcons),
    );
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select((s) => _parseAvatarStyle(s.avatarStyle)),
    );
    final sessionList = sessions.values.toList();

    // Mark as loaded once we get any data or sync is initialized.
    if (!_hasLoaded && (sessionList.isNotEmpty || sync.isInitialized)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasLoaded = true);
      });
    }

    final activeSessions = sessionList.where(isSessionActive).toList()
      ..sort((a, b) => b.activeAt.compareTo(a.activeAt));
    final inactiveSessions =
        sessionList.where((s) => !isSessionActive(s)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (sessionList.isEmpty && !_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sessionList.isEmpty) {
      return const EmptySessionsView();
    }

    // Trigger stagger animation once on first non-empty render.
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
        triggerStagger: triggerStagger,
        hideInactive: hideInactive,
        showFlavorIcons: showFlavorIcons,
        avatarStyle: avatarStyle,
      ),
    );
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
    // Group active sessions by path.
    final activeByPath = <String, List<Session>>{};
    for (final s in activeSessions) {
      final path = s.metadata?.path ?? 'Unknown';
      activeByPath.putIfAbsent(path, () => []).add(s);
    }

    // Build the flat list of items with their stagger indices.
    var staggerIndex = 0;

    final children = <Widget>[];

    // Active sessions section.
    if (activeSessions.isNotEmpty) {
      children.add(
        _FadeInSection(
          delay: Duration(milliseconds: _kStaggerStep * staggerIndex),
          child: _SectionHeader(title: context.l10n.sessionsActiveSessions),
        ),
      );

      for (final entry
          in (activeByPath.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))) {
        final pathKey = entry.key;
        final isPathCollapsed = _collapsedActivePaths.contains(pathKey);
        children.add(
          _FadeInSection(
            delay: Duration(milliseconds: _kStaggerStep * staggerIndex),
            child: _PathHeader(
              path: pathKey,
              sessionCount: entry.value.length,
              isCollapsed: isPathCollapsed,
              onToggle: () => setState(() {
                if (isPathCollapsed) {
                  _collapsedActivePaths.remove(pathKey);
                } else {
                  _collapsedActivePaths.add(pathKey);
                }
              }),
            ),
          ),
        );
        if (!isPathCollapsed) {
          for (final session in entry.value) {
            final capturedIndex = staggerIndex;
            final card = CompactActiveSessionCard(
              session: session,
              onTap: () => unawaited(
                context.pushNamed(
                  'chat',
                  pathParameters: {'sessionId': session.id},
                ),
              ),
              showFlavorIcon: showFlavorIcons,
              avatarStyle: avatarStyle,
              lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
            );
            children.add(
              _StaggeredSlideIn(
                index: capturedIndex,
                animate: triggerStagger,
                child: _DismissibleActiveSession(session: session, child: card),
              ),
            );
            staggerIndex++;
          }
        }
      }
    }

    // Archived sessions section.
    if (shouldShowInactiveSessionsSection(
      hideInactive: hideInactive,
      activeCount: activeSessions.length,
      inactiveCount: inactiveSessions.length,
    )) {
      children.add(
        _FadeInSection(
          delay: Duration(
            milliseconds: _kStaggerStep * staggerIndex,
          ),
          child: _ArchiveSectionHeader(
            count: inactiveSessions.length,
            grouping: _archivedGrouping,
            onGroupingChanged: (g) =>
                setState(() => _archivedGrouping = g),
          ),
        ),
      );

      final sel = _sel.value;
      final archivedItems = _archivedGrouping ==
              _ArchivedGrouping.folder
          ? _buildFolderGroupedItems(
              context,
              inactiveSessions,
              machines,
              startIndex: staggerIndex,
              animate: triggerStagger,
              showFlavorIcons: showFlavorIcons,
              avatarStyle: avatarStyle,
              selectionState: sel,
            )
          : _buildDateGroupedItems(
              context,
              inactiveSessions,
              startIndex: staggerIndex,
              animate: triggerStagger,
              showFlavorIcons: showFlavorIcons,
              avatarStyle: avatarStyle,
              selectionState: sel,
            );
      children.addAll(archivedItems);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      itemCount: children.length,
      itemBuilder: (ctx, i) => children[i],
    );
  }

  // ── Date-grouped archived items ──────────────────────

  List<Widget> _buildDateGroupedItems(
    BuildContext context,
    List<Session> sessions, {
    required int startIndex,
    required bool animate,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    required _SelectionState selectionState,
  }) {
    final dateItems = groupSessionsByExactDate(sessions);

    // Collect sessions per date group for counts and
    // collapse rendering.
    final groups = <String, List<Session>>{};
    String? currentDate;
    for (final item in dateItems) {
      switch (item) {
        case SessionHistoryDateHeader(:final date):
          currentDate = date;
          groups.putIfAbsent(date, () => []);
        case SessionHistorySession(:final session):
          if (currentDate != null) {
            groups[currentDate]!.add(session);
          }
      }
    }

    var itemIndex = startIndex;
    final widgets = <Widget>[];

    for (final entry in groups.entries) {
      final dateKey = entry.key;
      final dateSessions = entry.value;
      final isCollapsed =
          _collapsedDateKeys.contains(dateKey);

      widgets.add(
        _FadeInSection(
          delay: Duration(
            milliseconds: _kStaggerStep * itemIndex,
          ),
          child: _CollapsibleDateHeader(
            date: dateKey,
            sessionCount: dateSessions.length,
            isCollapsed: isCollapsed,
            onToggle: () => setState(() {
              if (_collapsedDateKeys.contains(dateKey)) {
                _collapsedDateKeys.remove(dateKey);
              } else {
                _collapsedDateKeys.add(dateKey);
              }
            }),
          ),
        ),
      );

      if (!isCollapsed) {
        for (var i = 0; i < dateSessions.length; i++) {
          final session = dateSessions[i];
          final capturedIndex = itemIndex;
          final isFirst = i == 0;
          final isLast = i == dateSessions.length - 1;
          final isSingle = dateSessions.length == 1;

          final card = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SessionCard(
                session: session,
                onTap: selectionState.isActive
                    ? () => _onSessionTapInSelectionMode(
                          session.id,
                        )
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
                isFirst: isFirst,
                isLast: isLast,
                isSingle: isSingle,
                compact: true,
                selectionMode: selectionState.isActive,
                isSelected: selectionState.selectedIds
                    .contains(session.id),
                showFlavorIcon: showFlavorIcons,
                avatarStyle: avatarStyle,
                lastMessageTimestamp:
                    sync.getLastMessageTimestamp(
                  session.id,
                ),
              ),
              if (!isLast && !isSingle)
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withAlpha(50),
                ),
            ],
          );

          final child = selectionState.isActive
              ? card
              : _DismissibleInactiveSession(
                  session: session,
                  child: card,
                );

          widgets.add(
            _StaggeredSlideIn(
              index: capturedIndex,
              animate: animate,
              child: child,
            ),
          );
          itemIndex++;
        }
      }
    }

    return widgets;
  }

  // ── Folder-grouped archived items ──────────────────

  List<Widget> _buildFolderGroupedItems(
    BuildContext context,
    List<Session> sessions,
    Map<String, Machine> machines, {
    required int startIndex,
    required bool animate,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
    required _SelectionState selectionState,
  }) {
    final folderItems =
        groupSessionsByFolder(sessions, machines);

    var itemIndex = startIndex;
    final widgets = <Widget>[];
    String? currentFolderKey;

    for (final item in folderItems) {
      switch (item) {
        case SessionFolderHeader():
          currentFolderKey = item.folderKey;
          final isCollapsed =
              _collapsedFolderKeys.contains(
            item.folderKey,
          );
          widgets.add(
            _FadeInSection(
              delay: Duration(
                milliseconds:
                    _kStaggerStep * itemIndex,
              ),
              child: _CollapsibleFolderHeader(
                header: item,
                isCollapsed: isCollapsed,
                onToggle: () => setState(() {
                  final key = item.folderKey;
                  if (_collapsedFolderKeys.contains(
                    key,
                  )) {
                    _collapsedFolderKeys.remove(key);
                  } else {
                    _collapsedFolderKeys.add(key);
                  }
                }),
              ),
            ),
          );
        case SessionFolderEntry():
          if (currentFolderKey != null &&
              _collapsedFolderKeys.contains(
                currentFolderKey,
              )) {
            continue;
          }
          final session = item.session;
          final capturedIndex = itemIndex;

          final card = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SessionCard(
                session: session,
                onTap: selectionState.isActive
                    ? () =>
                        _onSessionTapInSelectionMode(
                          session.id,
                        )
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
                isFirst: item.isFirst,
                isLast: item.isLast,
                isSingle: item.isSingle,
                compact: true,
                selectionMode: selectionState.isActive,
                isSelected: selectionState.selectedIds
                    .contains(session.id),
                showFlavorIcon: showFlavorIcons,
                avatarStyle: avatarStyle,
                lastMessageTimestamp:
                    sync.getLastMessageTimestamp(
                  session.id,
                ),
              ),
              if (!item.isLast && !item.isSingle)
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withAlpha(50),
                ),
            ],
          );

          final child = selectionState.isActive
              ? card
              : _DismissibleInactiveSession(
                  session: session,
                  child: card,
                );

          widgets.add(
            _StaggeredSlideIn(
              index: capturedIndex,
              animate: animate,
              child: child,
            ),
          );
          itemIndex++;
      }
    }

    return widgets;
  }
}

// ─── Dismissible wrappers ────────────────────────────────────────────────────

/// Dismissible wrapper for active sessions (swipe left → archive).
class _DismissibleActiveSession extends ConsumerWidget {
  const _DismissibleActiveSession({required this.session, required this.child});

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('active-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmArchive(context, ref),
      // Keep item visible after dismiss (data refresh handles removal).
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        color: cs.error,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: cs.onError, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.sessionsArchive,
              style: TextStyle(
                color: cs.onError,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  Future<bool> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.sessionsArchiveSession),
          content: Text(l10n.sessionsArchiveConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.sessionsArchive),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    try {
      await sync.killSession(session.id);
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive session: $e')),
        );
      }
      return false;
    }
  }
}

/// Dismissible wrapper for inactive sessions (swipe left → delete).
class _DismissibleInactiveSession extends ConsumerWidget {
  const _DismissibleInactiveSession({
    required this.session,
    required this.child,
  });

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('inactive-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, ref),
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        color: cs.error,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: cs.onError, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.commonDelete,
              style: TextStyle(
                color: cs.onError,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.chatDeleteSession),
          content: Text(l10n.sessionsDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    try {
      final success = await sync.deleteSession(session.id);
      if (success) {
        await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete session')),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete session: $e')));
      }
      return false;
    }
  }
}

// ─── Animation helpers ───────────────────────────────────────────────────────

/// Staggered slide-in animation wrapper.
///
/// Each card slides up from 24 px below its final position, with an
/// opacity fade, delayed by [index] * [_kStaggerStep] ms.
class _StaggeredSlideIn extends StatefulWidget {
  const _StaggeredSlideIn({
    required this.index,
    required this.animate,
    required this.child,
  });
  final int index;
  final bool animate;
  final Widget child;

  @override
  State<_StaggeredSlideIn> createState() => _StaggeredSlideInState();
}

class _StaggeredSlideInState extends State<_StaggeredSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _kSlideDuration),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animate) {
      final delay = Duration(milliseconds: _kStaggerStep * widget.index);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

/// Fade-in for non-card elements (headers).
class _FadeInSection extends StatefulWidget {
  const _FadeInSection({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_FadeInSection> createState() => _FadeInSectionState();
}

class _FadeInSectionState extends State<_FadeInSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

// ─── Section / header widgets ─────────────────────────────────────────────────

/// Path header for grouping active sessions by working directory.
/// Tappable to collapse/expand the group.
class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.path,
    required this.sessionCount,
    required this.isCollapsed,
    required this.onToggle,
  });
  final String path;
  final int sessionCount;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                path.split('/').last.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$sessionCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header for active / archived sessions.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Collapsible date section header with session count and
/// animated chevron. Tappable to collapse/expand the group.
class _CollapsibleDateHeader extends StatelessWidget {
  const _CollapsibleDateHeader({
    required this.date,
    required this.sessionCount,
    required this.isCollapsed,
    required this.onToggle,
  });

  final String date;
  final int sessionCount;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              '$sessionCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant
                    .withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible folder header showing the path + machine name.
class _CollapsibleFolderHeader extends StatelessWidget {
  const _CollapsibleFolderHeader({
    required this.header,
    required this.isCollapsed,
    required this.onToggle,
  });

  final SessionFolderHeader header;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header.displayPath,
                    style:
                        theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    header.machineName,
                    style:
                        theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant
                          .withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${header.sessionCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant
                    .withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Archive section header with grouping toggle (date / folder).
class _ArchiveSectionHeader extends StatelessWidget {
  const _ArchiveSectionHeader({
    required this.count,
    required this.grouping,
    required this.onGroupingChanged,
  });

  final int count;
  final _ArchivedGrouping grouping;
  final ValueChanged<_ArchivedGrouping> onGroupingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.sessionHistory} ($count)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _GroupingToggle(
            grouping: grouping,
            onChanged: onGroupingChanged,
          ),
        ],
      ),
    );
  }
}

/// Two-icon toggle for switching between date and folder
/// grouping.
class _GroupingToggle extends StatelessWidget {
  const _GroupingToggle({
    required this.grouping,
    required this.onChanged,
  });

  final _ArchivedGrouping grouping;
  final ValueChanged<_ArchivedGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleChip(
          icon: Icons.calendar_today_outlined,
          selected:
              grouping == _ArchivedGrouping.date,
          onTap: () =>
              onChanged(_ArchivedGrouping.date),
          tooltip: l10n.sessionsGroupByDate,
        ),
        const SizedBox(width: AppSpacing.xs),
        _ToggleChip(
          icon: Icons.folder_outlined,
          selected:
              grouping == _ArchivedGrouping.folder,
          onTap: () =>
              onChanged(_ArchivedGrouping.folder),
          tooltip: l10n.sessionsGroupByFolder,
        ),
      ],
    );
  }
}

/// Single icon chip used by [_GroupingToggle].
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Badge helpers ───────────────────────────────────────────────────────────

/// Circular checkbox shown at the leading edge in selection
/// mode, replacing the status color bar.
class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({
    required this.isSelected,
    required this.borderRadius,
  });

  final bool isSelected;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: borderRadius.topLeft,
          bottomLeft: borderRadius.bottomLeft,
        ),
      ),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? cs.primary : cs.surface,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 14,
                color: cs.onPrimary,
              )
            : null,
      ),
    );
  }
}

/// Draft icon overlay badge shown on avatar bottom-right corner.
class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: AppSpacing.lg,
        height: AppSpacing.lg,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.drive_file_rename_outline,
          size: 10,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Task progress badge shown near the timestamp/status area.
class _TodoProgressBadge extends StatelessWidget {
  const _TodoProgressBadge({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 10, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses an avatar style string to the corresponding [AvatarStyle] enum.
///
/// Returns null if the string doesn't match a known style
/// (causes hash-based selection).
AvatarStyle? _parseAvatarStyle(String? style) {
  return switch (style) {
    'gradient' => AvatarStyle.gradient,
    'pixelated' => AvatarStyle.pixelated,
    'brutalist' => AvatarStyle.brutalist,
    _ => null,
  };
}

/// Computes todo progress, returning (completed, total) or null if
/// todos are empty or all completed.
({int completed, int total})? _getTodoProgress(List<TodoItem>? todos) {
  if (todos == null || todos.isEmpty) return null;
  final total = todos.length;
  final completed = todos.where((t) => t.status == TodoState.completed).length;
  if (completed >= total) return null;
  return (completed: completed, total: total);
}

// ─── Active session card ─────────────────────────────────────────────────────

/// Active session card — clean, no glow animation.
class ActiveSessionCard extends StatelessWidget {
  const ActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  /// Timestamp of the last message in the session (ms since epoch).
  /// If null, falls back to session.updatedAt.
  final int? lastMessageTimestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(session.todos);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: cs.primary.withValues(alpha: 0.04),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Color(sessionStatus.statusDotColor),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'session-avatar-${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 44,
                                showFlavorIcon: showFlavorIcon,
                                style: avatarStyle,
                              ),
                              if (hasDraft) const _DraftBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sessionName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  AppStatusDot(
                                    color: Color(sessionStatus.statusDotColor),
                                    pulse: sessionStatus.isPulsing,
                                    size: 8,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sessionSubtitle,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ?? session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (todoProgress != null) ...[
                              const SizedBox(height: 3),
                              _TodoProgressBadge(
                                completed: todoProgress.completed,
                                total: todoProgress.total,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Compact active session card ─────────────────────────────────────────────

/// Compact active session row (~56px height, no glow/pulse border,
/// status dot inline left of title, smaller 36px avatar).
///
/// Shown when [Settings.compactSessionView] is enabled.
class CompactActiveSessionCard extends StatelessWidget {
  const CompactActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
  });

  /// The session to display.
  final Session session;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  /// Timestamp of the last message in the session (ms since epoch).
  /// If null, falls back to session.updatedAt.
  final int? lastMessageTimestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(session.todos);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: cs.primary.withValues(alpha: 0.04),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Color(sessionStatus.statusDotColor),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        // Small avatar with optional draft badge.
                        Hero(
                          tag: 'session-avatar-${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 36,
                                showFlavorIcon: showFlavorIcon,
                                style: avatarStyle,
                              ),
                              if (hasDraft) const _DraftBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sessionName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppStatusDot(
                                color: Color(sessionStatus.statusDotColor),
                                pulse: sessionStatus.isPulsing,
                                size: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ?? session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            if (todoProgress != null) ...[
                              const SizedBox(height: 2),
                              _TodoProgressBadge(
                                completed: todoProgress.completed,
                                total: todoProgress.total,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Archived session card ───────────────────────────────────────────────────

/// Session card widget with enhanced status display and avatars.
///
/// Matches React Native's CompactSessionRow implementation.
class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.onLongPress,
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
    this.compact = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.avatarStyle,
    this.lastMessageTimestamp,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Whether this is the first card in a group.
  final bool isFirst;

  /// Whether this is the last card in a group.
  final bool isLast;

  /// Whether this is the only card in a group.
  final bool isSingle;

  /// Whether to show a date header above the card.
  final bool showDateHeader;

  /// Whether to use compact layout.
  final bool compact;

  /// Whether multi-select mode is active.
  final bool selectionMode;

  /// Whether this card is currently selected.
  final bool isSelected;

  /// Whether to show the AI provider flavor icon.
  final bool showFlavorIcon;

  /// The avatar style (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  /// Timestamp of the last message (ms since epoch).
  final int? lastMessageTimestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(session.todos);

    // Determine card border-radius based on position within group.
    BorderRadius borderRadius;
    if (isSingle) {
      borderRadius = BorderRadius.circular(AppRadius.md);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(
        top: Radius.circular(AppRadius.md),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.md),
      );
    } else {
      borderRadius = BorderRadius.zero;
    }

    final titleColor = sessionStatus.isConnected
        ? cs.onSurface
        : cs.onSurfaceVariant;
    final cardColor = isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surface;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: isSelected
              ? BorderSide(
                  color:
                      cs.primary.withValues(alpha: 0.3),
                )
              : BorderSide.none,
        ),
        elevation: 0,
        color: cardColor,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                if (selectionMode)
                  _SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: borderRadius,
                  )
                else
                  Container(
                    width: 3,
                    color: sessionStatus.isConnected
                        ? Color(
                            sessionStatus.statusDotColor,
                          )
                        : cs.outlineVariant,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical:
                          compact ? 6 : AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag:
                              'session-avatar-${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: compact ? 36 : 44,
                                monochrome: !sessionStatus
                                    .isConnected,
                                showFlavorIcon:
                                    showFlavorIcon,
                                style: avatarStyle,
                              ),
                              if (hasDraft)
                                const _DraftBadge(),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: compact
                              ? AppSpacing.sm
                              : AppSpacing.md,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sessionName,
                                      style: theme
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                        color: titleColor,
                                      ),
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppSpacing.sm,
                                  ),
                                  AppStatusDot(
                                    color: sessionStatus
                                            .isConnected
                                        ? Color(
                                            sessionStatus
                                                .statusDotColor,
                                          )
                                        : cs
                                            .outlineVariant,
                                    pulse: sessionStatus
                                        .isPulsing,
                                    size: 8,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sessionSubtitle,
                                style: theme
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                  color: cs
                                      .onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ??
                                    session.updatedAt,
                                relative: true,
                              ),
                              style: theme
                                  .textTheme.labelSmall
                                  ?.copyWith(
                                color:
                                    cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (todoProgress !=
                                null) ...[
                              const SizedBox(
                                height: AppSpacing.xs,
                              ),
                              _TodoProgressBadge(
                                completed: todoProgress
                                    .completed,
                                total:
                                    todoProgress.total,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

/// Empty sessions view — clean, minimal design.
class EmptySessionsView extends StatelessWidget {
  const EmptySessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.computer_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.sessionNoSessionsYet,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.emptyMainScreenInstallCli,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.emptyMainScreenRunIt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.emptyMainScreenScanQrCode,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.tonal(
              onPressed: () =>
                  _SessionsListContent.showNewSessionDialog(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(l10n.sessionNewSession),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Connection status badge ─────────────────────────────────────────────────

/// Connection status badge in the app bar.
///
/// Shows a pulsing indicator while connecting.
class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({required this.status, super.key});

  /// The current connection status.
  final ConnectionStatus status;

  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ConnectionStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == ConnectionStatus.connecting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const connectedColor = Color(0xFF22C55E);
    final color = switch (widget.status) {
      ConnectionStatus.connected => connectedColor,
      ConnectionStatus.connecting => Colors.orange.shade600,
      ConnectionStatus.error => cs.error,
      ConnectionStatus.disconnected => cs.onSurfaceVariant,
    };

    final isConnecting = widget.status == ConnectionStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: isConnecting
            ? AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final opacity = 0.35 + 0.65 * _pulseAnimation.value;
                  final scale = 0.75 + 0.5 * _pulseAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: color.withValues(alpha: opacity),
                    ),
                  );
                },
              )
            : Icon(Icons.circle, size: 12, color: color),
      ),
    );
  }
}

// ─── New session dialog ──────────────────────────────────────────────────────

/// New session dialog.
class NewSessionDialog extends ConsumerStatefulWidget {
  const NewSessionDialog({super.key});

  @override
  ConsumerState<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends ConsumerState<NewSessionDialog> {
  String? _selectedPath;
  String? _selectedMachine;
  bool _isCreating = false;
  String? _createError;
  String _selectedAgent = 'claude';
  String _sessionType = 'simple';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final machines = ref
        .watch(machinesNotifierProvider)
        .values
        .where((m) => m.active)
        .toList();

    return AlertDialog(
      title: Text(l10n.newSessionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (machines.isEmpty)
            Text(l10n.newSessionNoMachinesFound)
          else
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.sessionMachine),
              initialValue: _selectedMachine,
              isExpanded: true,
              selectedItemBuilder: (context) => [
                Text(
                  l10n.sessionSelectMachine,
                  overflow: TextOverflow.ellipsis,
                ),
                ...machines.map(
                  (machine) => Text(
                    machine.metadata?.displayName ??
                        machine.metadata?.host ??
                        machine.id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.sessionSelectMachine),
                ),
                ...machines.map(
                  (machine) => DropdownMenuItem(
                    value: machine.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.computer,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            machine.metadata?.displayName ??
                                machine.metadata?.host ??
                                machine.id,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMachine = value;
                });
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (_selectedMachine == null) return const [];
              final sessions = ref.read(sessionsNotifierProvider);
              final paths = sessions.values
                  .where((s) => s.metadata?.machineId == _selectedMachine)
                  .map((s) => s.metadata?.path)
                  .whereType<String>()
                  .toSet()
                  .toList();
              if (textEditingValue.text.isEmpty) {
                return paths;
              }
              return paths.where(
                (p) => p.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              );
            },
            onSelected: (value) {
              setState(() => _selectedPath = value);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: l10n.sessionPath,
                      hintText: l10n.sessionPathHint,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedPath = value;
                        _createError = null;
                      });
                    },
                  );
                },
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'simple',
                label: Text(l10n.sessionsSimple),
                icon: const Icon(Icons.folder_outlined),
              ),
              ButtonSegment(
                value: 'worktree',
                label: Text(l10n.sessionsWorktree),
                icon: const Icon(Icons.account_tree_outlined),
              ),
            ],
            selected: {_sessionType},
            onSelectionChanged: (selection) {
              setState(() => _sessionType = selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'claude', label: Text(l10n.sessionsClaude)),
              ButtonSegment(value: 'codex', label: Text(l10n.sessionsCodex)),
              ButtonSegment(value: 'gemini', label: Text(l10n.sessionsGemini)),
            ],
            selected: {_selectedAgent},
            onSelectionChanged: (selection) {
              setState(() => _selectedAgent = selection.first);
            },
          ),
          if (_createError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _createError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed:
              !_isCreating &&
                  (_selectedPath?.isNotEmpty ?? false) &&
                  _selectedMachine != null &&
                  connectionStatus == ConnectionStatus.connected
              ? () => _createSession(context)
              : null,
          child: _isCreating
              ? const SizedBox(
                  width: AppSpacing.lg,
                  height: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonCreate),
        ),
      ],
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final machineId = _selectedMachine;
    final path = _selectedPath?.trim();
    if (machineId == null || path == null || path.isEmpty) return;

    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    try {
      await sync.applySettings({'lastUsedAgent': _selectedAgent});
      final String sessionPath;
      if (_sessionType == 'worktree') {
        sessionPath = await sync.createWorktree(
          machineId: machineId,
          basePath: path,
        );
      } else {
        sessionPath = path;
      }
      final sessionId = await sync.createSession(
        machineId: machineId,
        path: sessionPath,
      );
      if (!mounted) return;
      // Use refreshFromSync to ensure we fetch the latest
      // session data from server.
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      if (!mounted) return;
      navigator.pop();
      unawaited(
        router.pushNamed('chat', pathParameters: {'sessionId': sessionId}),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }
}
