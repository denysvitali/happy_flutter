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
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/app_visibility_coordinator.dart';
import '../../core/services/chat_switch_metrics.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/performance_context_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/sync/sync_subscription_mixin.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_utils.dart';
import '../../core/widgets/desktop_update_banner.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/sync_progress_bar.dart';
import '../chat/chat_screen.dart';
import '../loops/all_loops_screen.dart';
import '../providers/providers_usage_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/new_session_dialog.dart';
import 'widgets/session_collection_app_bar.dart';
import 'widgets/session_list_helpers.dart';
import 'widgets/sessions_list_content.dart';

part 'session_batch_actions.dart';

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
  const SessionsScreen({super.key, this.initialTab, this.sessionsApi});

  final String? initialTab;
  final SessionsApi? sessionsApi;

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
      // An unfocused desktop window is still connected and still receiving
      // every token an agent emits. Rebuilding the full home tree on each one
      // painted ~1.2M frames/7d in production with nobody watching. Skip the
      // repaint while unfocused and replay once on refocus instead: Sync keeps
      // running, so a single catch-up read shows the same final state.
      if (!AppFocusState.instance.isFocused) {
        _skippedWhileUnfocused = true;
        return;
      }
      _refreshSessionsFromSync();
    });
    AppFocusState.instance.addListener(_onAppFocusChanged);
  }

  /// Repaint-while-unfocused guard. Set when a Sync change arrived with the
  /// window unfocused; cleared by the catch-up read on refocus.
  bool _skippedWhileUnfocused = false;

  void _onAppFocusChanged() {
    if (!mounted) return;
    if (!AppFocusState.instance.isFocused) return;
    if (_skippedWhileUnfocused) {
      _skippedWhileUnfocused = false;
      _refreshSessionsFromSync();
    }
  }

  void _refreshSessionsFromSync() {
    if (!_sessionsRouteActive || _activeTab != AppTab.sessions) return;
    ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    ref.read(machinesNotifierProvider.notifier).loadFromSync();
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

  AppTab _parseTab(String? tab) => AppTab.values.firstWhere(
    (value) => value.name == tab,
    orElse: () => AppTab.sessions,
  );

  void _updateUrlTab(AppTab tab) {
    final router = GoRouter.of(context);
    final currentUri = router.routeInformationProvider.value.uri;

    if (currentUri.path == '/sessions') {
      final newTab = tab.name;
      final newUri = currentUri.replace(
        queryParameters: newTab == 'sessions' ? {} : {'tab': newTab},
      );
      router.replace(newUri.toString());
    }
  }

  @override
  void dispose() {
    AppFocusState.instance.removeListener(_onAppFocusChanged);
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
    final appBar = isTablet
        ? null
        : switch (_activeTab) {
            AppTab.sessions => _buildSessionsAppBar(context),
            AppTab.settings => AppBar(title: Text(l10n.settingsTitle)),
            AppTab.loops || AppTab.providers => null,
          };
    final sidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final badgeCounts = <AppTab, int>{AppTab.loops: totalActiveLoops};

    final tabContent = Column(
      children: [
        const OfflineBanner(),
        const DesktopUpdateBanner(),
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
          _folderNotifier.value == null &&
          !_selectionNotifier.value.isActive,
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
        } else if (!didPop && _selectionNotifier.value.isActive) {
          _exitSelectionMode();
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

  PreferredSizeWidget _buildSessionsAppBar(BuildContext context) {
    final sel = _selectionNotifier.value;
    if (sel.isActive) {
      return _buildSelectionAppBar(context, sel);
    }
    final folder = _folderNotifier.value;
    if (folder != null) {
      return SessionFolderAppBar(
        folder: folder,
        toolbarHeight: SessionFolderAppBar.heightOf(context),
        onBack: () => _folderNotifier.value = null,
        onCreate: (machineId, path) => _showNewSessionDialog(
          context,
          initialMachineId: machineId,
          initialPath: path,
        ),
      );
    }
    return _buildNormalSessionsAppBar(context);
  }

  PreferredSizeWidget _buildNormalSessionsAppBar(BuildContext context) =>
      SessionCollectionAppBar(
        searching: _isSearching,
        controller: _searchController,
        connectionStatus: ref.watch(connectionNotifierProvider),
        scrolled: _isScrolled,
        toolbarHeight: SessionCollectionAppBar.heightOf(
          context,
          searching: _isSearching,
        ),
        onStartSearch: () => setState(() => _isSearching = true),
        onCloseSearch: _clearSearch,
        onClearSearch: () {
          _searchDebounce?.cancel();
          _searchController.clear();
          setState(() {});
        },
        onQueryChanged: (_) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 250), () {
            if (mounted) setState(() {});
          });
        },
        onSubmitSearch: () {
          _searchDebounce?.cancel();
          setState(() {});
        },
        onCreate: () => _showNewSessionDialog(context),
      );

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    SelectionState sel,
  ) {
    final allIds = _allSelectableSessionIds();
    final allSelected =
        allIds.isNotEmpty && allIds.every(sel.selectedIds.contains);
    return SessionSelectionAppBar(
      count: sel.selectedIds.length,
      allSelected: allSelected,
      busy: sel.isBatchDeleting,
      hasActive: _hasActiveSessionsInSelection(sel),
      hasPinned: _hasPinnedInSelection(sel),
      actionsHeight: SessionSelectionAppBar.actionsHeightOf(context),
      onCancel: _exitSelectionMode,
      onSelectAll: () => _toggleSelectAll(allIds, allSelected),
      onArchive: () => _confirmBatchArchive(context, sel),
      onPin: () => _pinOrUnpinSelected(sel),
      onDelete: () => _confirmBatchDelete(context, sel),
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
        collapsibleOnDesktop: true,
        collapseBreakpoint: AppBreakpoint.masterDetail,
        dividerSemanticsLabel: context.l10n.sessionsResizeSidebar,
        master: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          appBar: _buildSessionsAppBar(context),
          body: SyncProgressOverlay(
            child: SessionsListContent(
              selectionNotifier: _selectionNotifier,
              folderNotifier: _folderNotifier,
              searchQuery: _searchController.text,
              onClearSearch: _clearSearch,
              scrollController: _scrollController,
              onCreateSession: () => _showNewSessionDialog(context),
              onCreateSessionOnMachine: (machineId) =>
                  _showNewSessionDialog(context, initialMachineId: machineId),
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
                // The pane lives inside this shell route, so its live
                // message updates must not be gated on the `chat` route.
                embedded: true,
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
        appBar: _buildSessionsAppBar(context),
        body: SyncProgressOverlay(
          child: SessionsListContent(
            selectionNotifier: _selectionNotifier,
            folderNotifier: _folderNotifier,
            searchQuery: _searchController.text,
            onClearSearch: _clearSearch,
            isVisible: true,
            scrollController: _scrollController,
            onCreateSession: () => _showNewSessionDialog(context),
            onCreateSessionOnMachine: (machineId) =>
                _showNewSessionDialog(context, initialMachineId: machineId),
          ),
        ),
      );
    }

    // Keep one stable stack so tab-local state (filters, scroll position,
    // selections) survives navigation and network-backed tabs do not repeat
    // their init loads. TickerMode pauses hidden tab animations.
    return IndexedStack(
      index: _activeTab.index,
      children: [
        TickerMode(
          enabled: _activeTab == AppTab.sessions,
          child: SessionsListContent(
            selectionNotifier: _selectionNotifier,
            folderNotifier: _folderNotifier,
            searchQuery: _searchController.text,
            onClearSearch: _clearSearch,
            isVisible: _activeTab == AppTab.sessions,
            scrollController: _scrollController,
            onCreateSession: () => _showNewSessionDialog(context),
            onCreateSessionOnMachine: (machineId) =>
                _showNewSessionDialog(context, initialMachineId: machineId),
          ),
        ),
        TickerMode(
          enabled: _activeTab == AppTab.loops,
          child: _buildLoopsTab(),
        ),
        TickerMode(
          enabled: _activeTab == AppTab.providers,
          child: _buildProvidersTab(),
        ),
        TickerMode(
          enabled: _activeTab == AppTab.settings,
          child: _buildSettingsTab(isTablet: isTablet),
        ),
      ],
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
    // An explicit selection is only replaced when the session is gone from
    // the collection (deleted). Archived sessions are not auto-selection
    // candidates, but tapping one must open *that* session — replacing it
    // with the most recent live session here opened the wrong chat.
    final currentStillExists = current != null && candidates.contains(current);
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
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() => _isSearching = false);
  }

  Set<String> _allSelectableSessionIds() {
    final scope = _selectionNotifier.value.selectableIds;
    if (scope != null) {
      final sessions = ref.read(sessionsNotifierProvider);
      return scope.where(sessions.containsKey).toSet();
    }
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

  void _exitSelectionMode({bool completed = false}) {
    if (_selectionNotifier.value.isBatchDeleting && !completed) return;
    _selectionNotifier.value = const SelectionState();
  }

  void _toggleSelectAll(Set<String> allIds, bool currentlyAllSelected) {
    final current = _selectionNotifier.value;
    if (current.isBatchDeleting) return;
    _selectionNotifier.value = current.copyWith(
      selectedIds: currentlyAllSelected ? {} : Set<String>.of(allIds),
    );
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

    // A create dialog cannot succeed without a reachable computer. Refresh
    // once to avoid acting on stale provider state, then route users to the
    // existing setup or recovery destination instead of a disabled form.
    var machines = ref.read(machinesNotifierProvider);
    if (!machines.values.any((machine) => machine.isOnline)) {
      await ref.read(machinesNotifierProvider.notifier).refreshFromSync();
      if (!mounted || !context.mounted) return;
      machines = ref.read(machinesNotifierProvider);
    }
    if (machines.isEmpty) {
      await router.pushNamed('link');
      if (mounted) {
        unawaited(
          ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
        );
      }
      return;
    }
    if (!machines.values.any((machine) => machine.isOnline)) {
      await router.pushNamed('machines');
      return;
    }

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
