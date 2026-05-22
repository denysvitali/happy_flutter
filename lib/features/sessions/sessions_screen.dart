import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/sessions_api.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_utils.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import '../../core/widgets/sync_progress_bar.dart';
import '../chat/chat_screen.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/connection_status_badge.dart';
import 'widgets/new_session_dialog.dart';
import 'widgets/session_list_helpers.dart';
import 'widgets/sessions_list_content.dart';

enum _NavigationAction {
  switchToSessions,
  closeFolder,
  closeTabletChat,
  exitConfirm,
}

/// Sessions list screen with date grouping and enhanced
/// status display.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen>
    with SyncSubscriptionMixin {
  late AppTab _activeTab;
  late final Set<AppTab> _builtTabs;
  final _selectionNotifier = ValueNotifier<SelectionState>(
    const SelectionState(),
  );
  final _folderNotifier = ValueNotifier<SessionFolderHeader?>(null);
  final _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _searchDebounce;

  /// Drives the 1dp AppBar bottom border — true once the list
  /// has scrolled past its initial position.
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  /// Tracks a pending navigation action so that canPop remains false
  /// for the duration of the async setState, preventing rapid back
  /// presses from racing with state updates.
  _NavigationAction? _pendingNav;

  /// The currently selected session ID when running on a tablet-sized screen.
  /// On phone, navigation is handled via pushed routes (no in-place selection).
  String? _selectedSessionId;

  void _onScroll() {
    final scrolled = _scrollController.offset > 0;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  void initState() {
    super.initState();
    _activeTab = _parseTab(widget.initialTab);
    _builtTabs = <AppTab>{_activeTab};
    _selectionNotifier.addListener(_onSelectionChanged);
    _folderNotifier.addListener(_onFolderChanged);
    _scrollController.addListener(_onScroll);
    Future<void>.microtask(() async {
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
    });
    subscribeToDomains(
      {SyncDomain.sessions, SyncDomain.machines},
      () {
        ref.read(sessionsNotifierProvider.notifier).loadFromSync();
        ref.read(machinesNotifierProvider.notifier).loadFromSync();
      },
    );
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _onFolderChanged() {
    if (mounted) setState(() {});
  }

  AppTab _parseTab(String? tab) {
    return switch (tab) {
      'settings' => AppTab.settings,
      'inbox' => AppTab.inbox,
      'sessions' => AppTab.sessions,
      _ => AppTab.sessions,
    };
  }

  String _tabToString(AppTab tab) {
    return switch (tab) {
      AppTab.sessions => 'sessions',
      AppTab.inbox => 'inbox',
      AppTab.settings => 'settings',
    };
  }

  void _updateUrlTab(AppTab tab) {
    final router = GoRouter.of(context);
    final currentUri = router.routeInformationProvider.value.uri;

    if (currentUri.path == '/sessions') {
      final newTab = _tabToString(tab);
      final newUri = currentUri.replace(
        queryParameters: newTab == 'sessions' ? {} : {'tab': newTab},
      );
      router.replace(newUri.toString());
    }
  }

  @override
  void dispose() {
    _selectionNotifier
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _folderNotifier
      ..removeListener(_onFolderChanged)
      ..dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= AppBreakpoint.tablet;
    final isSessionsTabOnTablet = isTablet && _activeTab == AppTab.sessions;
    final isTabletDetail = isSessionsTabOnTablet && _selectedSessionId != null;
    // On tablet's sessions tab, the master pane owns the sessions AppBar
    // (search/+/selection/folder modes only affect the list) and the detail
    // pane is `ChatScreen`, which has its own AppBar. The outer Scaffold
    // therefore has no AppBar — otherwise we'd render two stacked headers
    // and selection/folder mode would replace the detail pane's header.
    final appBar = isSessionsTabOnTablet
        ? null
        : _buildAppBar(context, l10n);

    return PopScope(
      // Always block if a navigation action is already pending —
      // read current state at callback time rather than relying on
      // the build-time value to avoid races with async setState.
      canPop:
          !isTablet &&
          _pendingNav == null &&
          _activeTab == AppTab.sessions &&
          _folderNotifier.value == null,
      onPopInvokedWithResult: (didPop, _) {
        if (_pendingNav != null) return;
        final currentTab = _activeTab;
        final folder = _folderNotifier.value;
        if (!didPop && currentTab != AppTab.sessions) {
          _pendingNav = _NavigationAction.switchToSessions;
          setState(() {
            _activeTab = AppTab.sessions;
            _pendingNav = null;
          });
          _updateUrlTab(AppTab.sessions);
        } else if (!didPop &&
            isTablet &&
            currentTab == AppTab.sessions &&
            _selectedSessionId != null) {
          _pendingNav = _NavigationAction.closeTabletChat;
          setState(() {
            _selectedSessionId = null;
            _pendingNav = null;
          });
        } else if (!didPop && currentTab == AppTab.sessions && folder != null) {
          _pendingNav = _NavigationAction.closeFolder;
          setState(() {
            _folderNotifier.value = null;
            _pendingNav = null;
          });
        } else if (!didPop && currentTab == AppTab.sessions) {
          final now = DateTime.now();
          if (_lastBackPressTime == null ||
              now.difference(_lastBackPressTime!) >
                  const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            _pendingNav = _NavigationAction.exitConfirm;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.sessionsPressBackToExit),
                duration: const Duration(seconds: 2),
              ),
            );
            _pendingNav = null;
          }
        }
      },
      child: Scaffold(
        appBar: appBar,
        body: SafeArea(
          top: appBar == null,
          bottom: false,
          child: isSessionsTabOnTablet
              ? _buildCurrentTabContent()
              : SyncProgressOverlay(child: _buildCurrentTabContent()),
        ),
        bottomNavigationBar: isTabletDetail
            ? null
            : TabBar(
                activeTab: _activeTab,
                onTabPress: _setActiveTab,
              ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (_activeTab == AppTab.sessions) {
      return _buildSessionsAppBar(context, l10n);
    }
    if (_activeTab == AppTab.inbox) {
      return AppBar(title: const Text('Inbox'));
    }
    if (_activeTab == AppTab.settings) {
      return AppBar(title: Text(l10n.settingsTitle));
    }
    return null;
  }

  PreferredSizeWidget _buildSessionsAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final sel = _selectionNotifier.value;
    if (sel.isActive) {
      return _buildSelectionAppBar(context, l10n, sel);
    }
    final folder = _folderNotifier.value;
    if (folder != null) {
      return _buildFolderAppBar(context, l10n, folder);
    }
    return _buildNormalSessionsAppBar(context, l10n);
  }

  AppBar _buildFolderAppBar(
    BuildContext context,
    AppLocalizations l10n,
    SessionFolderHeader folder,
  ) {
    final cs = Theme.of(context).colorScheme;
    // Extract machineId and raw path from folderKey ('machineId:path').
    final colonIndex = folder.folderKey.indexOf(':');
    final machineId = colonIndex > 0
        ? folder.folderKey.substring(0, colonIndex)
        : null;
    final rawPath = colonIndex > 0 && colonIndex < folder.folderKey.length - 1
        ? folder.folderKey.substring(colonIndex + 1)
        : null;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: l10n.commonBack,
        onPressed: () => _folderNotifier.value = null,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            folder.displayPath,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${folder.machineName}'
            ' \u2022 ${folder.sessionCount}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.sessionsNew,
          onPressed: () => _showNewSessionDialog(
            context,
            initialMachineId: machineId,
            initialPath: rawPath,
          ),
        ),
      ],
    );
  }

  AppBar _buildNormalSessionsAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final connectionStatus = ref.watch(connectionNotifierProvider);

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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.commonSearch,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.smd,
              ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) setState(() {});
              });
            },
          ),
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
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.sessionsNew,
          onPressed: () => _showNewSessionDialog(context),
        ),
      ],
      bottom: _isScrolled
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            )
          : null,
    );
  }

  AppBar _buildSelectionAppBar(
    BuildContext context,
    AppLocalizations l10n,
    SelectionState sel,
  ) {
    final cs = Theme.of(context).colorScheme;
    final allIds = _allSelectableSessionIds();
    final allSelected =
        allIds.isNotEmpty && allIds.every(sel.selectedIds.contains);
    final hasActiveSelected = _hasActiveSessionsInSelection(sel);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.commonCancel,
        onPressed: _exitSelectionMode,
      ),
      title: Text(l10n.sessionsSelectedCount(sel.selectedIds.length)),
      actions: [
        TextButton(
          onPressed: sel.isBatchDeleting
              ? null
              : () => _toggleSelectAll(allIds, allSelected),
          child: Text(
            allSelected ? l10n.sessionsDeselectAll : l10n.sessionsSelectAll,
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
            onPressed: (sel.selectedIds.isEmpty || sel.isBatchDeleting)
                ? null
                : () => _confirmBatchArchive(context, sel),
          ),
        IconButton(
          icon: Icon(
            _hasPinnedInSelection(sel)
                ? Icons.push_pin
                : Icons.push_pin_outlined,
          ),
          tooltip: _hasPinnedInSelection(sel)
              ? l10n.sessionsUnpin
              : l10n.sessionsPin,
          onPressed: sel.selectedIds.isEmpty
              ? null
              : () => _pinOrUnpinSelected(sel),
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
              : Icon(Icons.delete_outline, color: cs.error),
          tooltip: l10n.commonDelete,
          onPressed: (sel.selectedIds.isEmpty || sel.isBatchDeleting)
              ? null
              : () => _confirmBatchDelete(context, sel),
        ),
      ],
    );
  }

  Widget _buildCurrentTabContent() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= AppBreakpoint.tablet;

    // Tablet: sessions tab uses master-detail layout. Master and detail each
    // own their own AppBar (the outer Scaffold has none), so selection /
    // folder / search modes affect only the master pane and the chat detail
    // keeps `ChatAppBar` visible at all times.
    if (isTablet && _activeTab == AppTab.sessions) {
      return Row(
        children: [
          SizedBox(
            width: AppBreakpoint.sidebarMax.toDouble(),
            child: Scaffold(
              appBar: _buildSessionsAppBar(context, context.l10n),
              body: SyncProgressOverlay(
                child: SessionsListContent(
                  selectionNotifier: _selectionNotifier,
                  folderNotifier: _folderNotifier,
                  searchQuery: _searchController.text,
                  onClearSearch: _clearSearch,
                  scrollController: _scrollController,
                  onSessionTap: (sessionId) {
                    setState(() => _selectedSessionId = sessionId);
                  },
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _selectedSessionId != null
                ? ChatScreen(
                    // The key forces a fresh _ChatScreenState whenever
                    // the user picks a different session in the master
                    // pane, so initState re-runs the cache load,
                    // settings load, and sync subscriptions for the new
                    // session id. Without it, didUpdateWidget would
                    // reset state but never re-subscribe, leaving the
                    // chat stuck on a shimmer.
                    key: ValueKey<String>(_selectedSessionId!),
                    sessionId: _selectedSessionId!,
                    onBack: () =>
                        setState(() => _selectedSessionId = null),
                  )
                : _buildNoSessionSelected(),
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: AppDuration.fast,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<AppTab>(_activeTab),
        child: IndexedStack(
          index: _activeTab.index,
          children: [
            SessionsListContent(
              selectionNotifier: _selectionNotifier,
              folderNotifier: _folderNotifier,
              searchQuery: _searchController.text,
              onClearSearch: _clearSearch,
              scrollController: _scrollController,
            ),
            _buildInboxTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSessionSelected() {
    return AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: context.l10n.chatChat,
      subtitle: context.l10n.sessionNoSessionsYet,
    );
  }

  Widget _buildInboxTab() {
    if (_builtTabs.contains(AppTab.inbox)) {
      return const InboxScreen();
    }
    return const SizedBox.shrink();
  }

  Widget _buildSettingsTab() {
    if (_builtTabs.contains(AppTab.settings)) {
      return const SettingsScreen(embedded: true);
    }
    return const SizedBox.shrink();
  }

  void _setActiveTab(AppTab tab) {
    setState(() {
      _activeTab = tab;
      _builtTabs.add(tab);
    });
    _updateUrlTab(tab);
  }

  // ── Selection helpers ─────────────────────────

  void _clearSearch() {
    _searchController.clear();
    setState(() => _isSearching = false);
  }

  Set<String> _allSelectableSessionIds() {
    final sessions = ref.read(sessionsNotifierProvider);
    final folder = _folderNotifier.value;
    if (folder == null) {
      return sessions.values.map((s) => s.id).toSet();
    }
    // Select-all in folder view must match what the list actually displays —
    // only sessions in this folder's `'${machineId}:${path}'` group.
    return sessions.values
        .where((s) => sessionFolderKey(s) == folder.folderKey)
        .map((s) => s.id)
        .toSet();
  }

  bool _hasActiveSessionsInSelection(SelectionState sel) {
    final sessions = ref.read(sessionsNotifierProvider);
    return sel.selectedIds.any((id) {
      final s = sessions[id];
      return s != null && isSessionActive(s);
    });
  }

  bool _hasPinnedInSelection(SelectionState sel) {
    final sessions = ref.read(sessionsNotifierProvider);
    return sel.selectedIds.any((id) => sessions[id]?.pinned ?? false);
  }

  Future<void> _pinOrUnpinSelected(SelectionState sel) async {
    final sessions = ref.read(sessionsNotifierProvider);
    final notifier = ref.read(sessionsNotifierProvider.notifier);
    final hasPinned = _hasPinnedInSelection(sel);
    for (final id in sel.selectedIds) {
      final session = sessions[id];
      if (session == null) continue;
      if (hasPinned) {
        if (session.pinned) await notifier.unpinSession(id);
      } else {
        if (!session.pinned) await notifier.pinSession(id);
      }
    }
  }

  void _exitSelectionMode() {
    _selectionNotifier.value = const SelectionState();
  }

  void _toggleSelectAll(Set<String> allIds, bool currentlyAllSelected) {
    final current = _selectionNotifier.value;
    _selectionNotifier.value = current.copyWith(
      selectedIds: currentlyAllSelected ? {} : Set<String>.of(allIds),
    );
  }

  Future<void> _confirmBatchArchive(
    BuildContext context,
    SelectionState sel,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sessions = ref.read(sessionsNotifierProvider);
    final activeIds = sel.selectedIds.where((id) {
      final s = sessions[id];
      return s != null && isSessionActive(s);
    }).toList();
    if (activeIds.isEmpty) return;

    final count = activeIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(dl10n.sessionsArchiveSession),
          content: Text(dl10n.sessionsArchiveNConfirm(count)),
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

    _selectionNotifier.value = sel.copyWith(isBatchDeleting: true);

    var failCount = 0;
    for (final id in activeIds) {
      try {
        await SessionsApi().setSessionArchived(id, true);
        sync.markSessionArchived(id);
      } catch (e, st) {
        logger.error(
          'Failed to archive session in batch: '
          'sessionId=$id',
          e,
          st,
        );
        failCount++;
      }
    }

    if (mounted) {
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    }

    _exitSelectionMode();

    if (failCount > 0 && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sessionsArchivePartialFail(failCount))),
      );
    }
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    SelectionState sel,
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
          content: Text(dl10n.sessionsDeleteNConfirm(count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    _selectionNotifier.value = sel.copyWith(isBatchDeleting: true);

    final ids = List<String>.from(sel.selectedIds);

    final failCount = await ref
        .read(sessionsNotifierProvider.notifier)
        .optimisticBatchDelete(ids);

    _exitSelectionMode();

    if (failCount > 0 && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sessionsDeletePartialFail(failCount))),
      );
    }
  }

  Future<void> _showNewSessionDialog(
    BuildContext context, {
    String? initialMachineId,
    String? initialPath,
  }) async {
    final isTablet = MediaQuery.sizeOf(context).width >= AppBreakpoint.tablet;
    final router = GoRouter.of(context);
    final sessionId = await showDialog<String>(
      context: context,
      builder: (_) => NewSessionDialog(
        initialMachineId: initialMachineId,
        initialPath: initialPath,
      ),
    );
    if (sessionId == null || !mounted) return;
    if (isTablet) {
      setState(() => _selectedSessionId = sessionId);
    } else {
      unawaited(
        router.pushNamed('chat', pathParameters: {'sessionId': sessionId}),
      );
    }
  }
}
