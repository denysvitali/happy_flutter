import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/sessions_api.dart';
import '../../core/components/sidebar/app_sidebar.dart';
import '../../core/components/tablet/no_session_selected_view.dart';
import '../../core/components/tablet/resizable_split_view.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/chat_switch_metrics.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/performance_context_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/sync/sync_subscription_mixin.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_utils.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/sync_progress_bar.dart';
import '../chat/chat_screen.dart';
import '../loops/all_loops_screen.dart';
import '../providers/providers_usage_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/connection_status_badge.dart';
import 'widgets/new_session_dialog.dart';
import 'widgets/session_headers.dart';
import 'widgets/session_list_helpers.dart';
import 'widgets/sessions_list_content.dart';

/// Persistence key for the sessions master-pane width in the tablet
/// split layout.
const String sessionsPaneId = 'sessions';

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
  bool _tabletSelectionDismissed = false;
  late bool _sessionsRouteActive;

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
    _sessionsRouteActive = isSessionsCollectionRoute(
      PerformanceContextService().currentRoute,
    );
    PerformanceContextService().routeListenable.addListener(_onRouteChanged);
    Future<void>.microtask(() {
      final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
      sessionsNotifier.loadFromSync();
      unawaited(sessionsNotifier.refreshFromSync(includeMachines: true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final machinesNotifier = ref.read(machinesNotifierProvider.notifier);
        machinesNotifier.loadFromSync();
      });
    });
    subscribeToDomains({SyncDomain.sessions, SyncDomain.machines}, () {
      if (!_sessionsRouteActive || _activeTab != AppTab.sessions) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
    });
  }

  void _onRouteChanged() {
    final active = isSessionsCollectionRoute(
      PerformanceContextService().currentRoute,
    );
    if (active == _sessionsRouteActive) return;
    _sessionsRouteActive = active;
    if (!active || !mounted || _activeTab != AppTab.sessions) return;
    ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    ref.read(machinesNotifierProvider.notifier).loadFromSync();
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
      'providers' => AppTab.providers,
      'loops' => AppTab.loops,
      'sessions' => AppTab.sessions,
      _ => AppTab.sessions,
    };
  }

  String _tabToString(AppTab tab) {
    return switch (tab) {
      AppTab.sessions => 'sessions',
      AppTab.loops => 'loops',
      AppTab.providers => 'providers',
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
    PerformanceContextService().routeListenable.removeListener(_onRouteChanged);
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
    final usesMasterDetail =
        screenWidth >= AppBreakpoint.masterDetail &&
        _activeTab == AppTab.sessions;
    if (usesMasterDetail) {
      _ensureTabletSelection();
    }
    // Active-loop count surfaced as a tab badge. Paused or expired loops
    // do NOT count — only loops that are still scheduled to fire. The
    // watch is scoped to the count shape so unrelated loop mutations
    // (e.g. prompt text) don't rebuild the tab bar — without `.select`,
    // LoopsNotifier.loadFromSync publishes a brand-new Map on every
    // counter tick, which `ref.watch(map) == ref.watch(map)` would
    // compare as unequal and rebuild the entire sessions screen even
    // when the count is unchanged.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final totalActiveLoops = ref.watch(
      loopsNotifierProvider.select(
        (state) => state.values
            .expand((l) => l)
            .where((l) => !l.isExpired(nowMs: nowMs))
            .length,
      ),
    );
    // On tablet's sessions tab, the master pane owns the sessions AppBar
    // (search/+/selection/folder modes only affect the list) and the detail
    // pane is `ChatScreen`, which has its own AppBar. The outer Scaffold
    // therefore has no AppBar — otherwise we'd render two stacked headers
    // and selection/folder mode would replace the detail pane's header.
    final appBar = isTablet ? null : _buildAppBar(context, l10n);
    final sidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final badgeCounts = <AppTab, int>{AppTab.loops: totalActiveLoops};

    final tabContent = Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: SafeArea(
            top: appBar == null,
            bottom: false,
            child: isSessionsTabOnTablet
                ? _buildCurrentTabContent(
                    isTablet: isTablet,
                    usesMasterDetail: usesMasterDetail,
                  )
                : SyncProgressOverlay(
                    child: _buildCurrentTabContent(
                      isTablet: isTablet,
                      usesMasterDetail: usesMasterDetail,
                    ),
                  ),
          ),
        ),
      ],
    );

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
            _tabletSelectionDismissed = true;
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
        body: ResponsiveNavLayout(
          activeTab: _activeTab,
          onTabPress: _setActiveTab,
          isCollapsed: sidebarCollapsed,
          onToggleCollapsed: () =>
              ref.read(sidebarCollapsedProvider.notifier).toggle(),
          badgeCounts: badgeCounts,
          child: tabContent,
        ),
        bottomNavigationBar: isTablet
            ? null
            : TabBar(
                activeTab: _activeTab,
                onTabPress: _setActiveTab,
                badgeCounts: badgeCounts,
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
    if (_activeTab == AppTab.settings) {
      return AppBar(title: Text(l10n.settingsTitle));
    }
    // Loops and providers tabs render their own Scaffold+AppBar (the embedded
    // AllLoopsScreen / ProvidersUsageScreen), so the outer Scaffold must not
    // add one — otherwise two stacked headers appear on phone layouts.
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
            '${folder.machineName} • '
            '${folderBreakdownLabel(context, folder)}',
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
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
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

  Widget _buildCurrentTabContent({
    required bool isTablet,
    required bool usesMasterDetail,
  }) {
    // Tablet: sessions tab uses master-detail layout. Master and detail each
    // own their own AppBar (the outer Scaffold has none), so selection /
    // folder / search modes affect only the master pane and the chat detail
    // keeps `ChatAppBar` visible at all times.
    if (usesMasterDetail && _activeTab == AppTab.sessions) {
      return ResizableSplitView(
        paneId: sessionsPaneId,
        dividerSemanticsLabel: context.l10n.sessionsResizeSidebar,
        master: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          appBar: _buildSessionsAppBar(context, context.l10n),
          body: SyncProgressOverlay(
            child: SessionsListContent(
              selectionNotifier: _selectionNotifier,
              folderNotifier: _folderNotifier,
              searchQuery: _searchController.text,
              onClearSearch: _clearSearch,
              scrollController: _scrollController,
              onCreateSession: () => _showNewSessionDialog(context),
              onSessionTap: (sessionId) {
                setState(() {
                  _selectedSessionId = sessionId;
                  _tabletSelectionDismissed = false;
                });
              },
            ),
          ),
        ),
        detail: _selectedSessionId != null
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
                onBack: () => setState(() {
                  _selectedSessionId = null;
                  _tabletSelectionDismissed = true;
                }),
              )
            : _buildNoSessionSelected(),
      );
    }

    if (isTablet && _activeTab == AppTab.sessions) {
      return Scaffold(
        appBar: _buildSessionsAppBar(context, context.l10n),
        body: SyncProgressOverlay(
          child: SessionsListContent(
            selectionNotifier: _selectionNotifier,
            folderNotifier: _folderNotifier,
            searchQuery: _searchController.text,
            onClearSearch: _clearSearch,
            isVisible: true,
            scrollController: _scrollController,
            onCreateSession: () => _showNewSessionDialog(context),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppDuration.fast),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
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
              isVisible: _activeTab == AppTab.sessions,
              scrollController: _scrollController,
              onCreateSession: () => _showNewSessionDialog(context),
            ),
            _buildLoopsTab(),
            _buildProvidersTab(),
            _buildSettingsTab(isTablet: isTablet),
          ],
        ),
      ),
    );
  }

  void _ensureTabletSelection() {
    final candidates = ref.watch(
      sessionsNotifierProvider.select(
        TabletSessionSelectionProjection.fromSessions,
      ),
    );
    if (candidates.sessionIds.isEmpty) return;
    final current = _selectedSessionId;
    final currentStillExists =
        current != null && candidates.sessionIds.contains(current);
    if (currentStillExists || (current == null && _tabletSelectionDismissed)) {
      return;
    }
    final next = candidates.sessionIds.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedSessionId == next) return;
      setState(() => _selectedSessionId = next);
    });
  }

  Widget _buildNoSessionSelected() {
    return NoSessionSelectedView(
      onCreateSession: () => _showNewSessionDialog(context),
    );
  }

  Widget _buildSettingsTab({required bool isTablet}) {
    if (_builtTabs.contains(AppTab.settings)) {
      return SettingsScreen(embedded: !isTablet);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoopsTab() {
    if (_builtTabs.contains(AppTab.loops)) {
      return const AllLoopsScreen();
    }
    return const SizedBox.shrink();
  }

  Widget _buildProvidersTab() {
    if (_builtTabs.contains(AppTab.providers)) {
      return const ProvidersUsageScreen();
    }
    return const SizedBox.shrink();
  }

  void _setActiveTab(AppTab tab) {
    setState(() {
      _activeTab = tab;
      _builtTabs.add(tab);
    });
    if (tab == AppTab.sessions && _sessionsRouteActive) {
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
    }
    _updateUrlTab(tab);
  }

  // ── Selection helpers ─────────────────────────

  void _clearSearch() {
    _searchController.clear();
    setState(() => _isSearching = false);
  }

  Set<String> _allSelectableSessionIds() {
    return selectableSessionIds(
      sessions: ref.read(sessionsNotifierProvider).values,
      hideInactive: ref.read(settingsNotifierProvider).hideInactiveSessions,
      folder: _folderNotifier.value,
    );
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
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionsArchiveSession,
      content: l10n.sessionsArchiveNConfirm(count),
      confirmLabel: l10n.sessionsArchive,
    );
    if (!confirmed) return;

    _selectionNotifier.value = sel.copyWith(isBatchDeleting: true);

    var failCount = 0;
    for (final id in activeIds) {
      try {
        await SessionsApi().setSessionArchived(id, true);
        await ref
            .read(sessionsNotifierProvider.notifier)
            .markSessionArchived(id, true);
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
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chatDeleteSession,
      content: l10n.sessionsDeleteNConfirm(count),
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed) return;

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
    final width = MediaQuery.sizeOf(context).width;
    final usesMasterDetail =
        width >= AppBreakpoint.masterDetail && _activeTab == AppTab.sessions;
    final router = GoRouter.of(context);
    final sessionId = await showNewSessionDialog(
      context,
      initialMachineId: initialMachineId,
      initialPath: initialPath,
    );
    if (sessionId == null || !mounted) return;
    ChatSwitchMetrics().begin(sessionId, source: 'new_session');
    // Only the master-detail branch (≥736) reads `_selectedSessionId`.
    // Compact tablet (600–735) is list-only — it must pushNamed like phone.
    if (usesMasterDetail) {
      setState(() => _selectedSessionId = sessionId);
    } else {
      unawaited(
        router.pushNamed('chat', pathParameters: {'sessionId': sessionId}),
      );
    }
  }
}
