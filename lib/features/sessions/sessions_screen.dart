import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/sessions_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_utils.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/sync_progress_bar.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/connection_status_badge.dart';
import 'widgets/new_session_dialog.dart';
import 'widgets/session_list_helpers.dart';
import 'widgets/sessions_list_content.dart';

enum _NavigationAction { switchToSessions, closeFolder, exitConfirm }

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
  /// Tracks a pending navigation action so that canPop remains false
  /// for the duration of the async setState, preventing rapid back
  /// presses from racing with state updates.
  _NavigationAction? _pendingNav;

  @override
  void initState() {
    super.initState();
    _activeTab = _parseTab(widget.initialTab);
    _builtTabs = <AppTab>{_activeTab};
    _selectionNotifier.addListener(_onSelectionChanged);
    _folderNotifier.addListener(_onFolderChanged);
    Future<void>.microtask(() async {
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
    });
    subscribeToDomains(
      {SyncDomain.sessions, SyncDomain.machines, SyncDomain.todos},
      () {
        ref.read(sessionsNotifierProvider.notifier).loadFromSync();
        ref.read(machinesNotifierProvider.notifier).loadFromSync();
        ref.read(todoStateNotifierProvider.notifier).loadFromSync();
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
      // Always block if a navigation action is already pending —
      // read current state at callback time rather than relying on
      // the build-time value to avoid races with async setState.
      canPop: _pendingNav == null &&
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
            currentTab == AppTab.sessions &&
            folder != null) {
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
        appBar: _buildAppBar(context, l10n),
        body: Column(
          children: [
            const SyncProgressBar(),
            const OfflineBanner(),
            Expanded(child: _buildCurrentTabContent()),
          ],
        ),
        bottomNavigationBar: TabBar(
          activeTab: _activeTab,
          onTabPress: _setActiveTab,
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
    if (_activeTab == AppTab.settings) {
      return AppBar(); // SettingsScreen has its own Scaffold/AppBar
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
    final machineId =
        colonIndex > 0 ? folder.folderKey.substring(0, colonIndex) : null;
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${folder.machineName}'
            ' \u2022 ${folder.sessionCount}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
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
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.commonSearch,
            border: InputBorder.none,
          ),
          onChanged: (_) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() {});
            });
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
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.sessionsNew,
          onPressed: () => _showNewSessionDialog(context),
        ),
      ],
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
        _buildInboxTab(),
        SessionsListContent(
          selectionNotifier: _selectionNotifier,
          folderNotifier: _folderNotifier,
          searchQuery: _searchController.text,
          onClearSearch: _clearSearch,
        ),
        _buildSettingsTab(),
      ],
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
      return const SettingsScreen();
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

  static Future<void> _showNewSessionDialog(
    BuildContext context, {
    String? initialMachineId,
    String? initialPath,
  }) async {
    final sessionId = await showDialog<String>(
      context: context,
      builder: (context) => NewSessionDialog(
        initialMachineId: initialMachineId,
        initialPath: initialPath,
      ),
    );
    if (!context.mounted || sessionId == null || sessionId.isEmpty) {
      return;
    }
    unawaited(
      context.pushNamed('chat', pathParameters: {'sessionId': sessionId}),
    );
  }
}
