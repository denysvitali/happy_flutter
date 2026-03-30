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
import '../../core/widgets/offline_banner.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/connection_status_badge.dart';
import 'widgets/new_session_dialog.dart';
import 'widgets/sessions_list_content.dart';

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
  final _selectionNotifier =
      ValueNotifier<SelectionState>(
    const SelectionState(),
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
        if (!didPop &&
            _activeTab != AppTab.sessions) {
          setState(
              () => _activeTab = AppTab.sessions);
          _updateUrlTab(AppTab.sessions);
        } else if (!didPop &&
            _activeTab == AppTab.sessions) {
          final now = DateTime.now();
          if (_lastBackPressTime == null ||
              now.difference(_lastBackPressTime!) >
                  const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context)
                .showSnackBar(
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
      return _buildSelectionAppBar(
          context, l10n, sel);
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
        ConnectionStatusBadge(
            status: connectionStatus),
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
    SelectionState sel,
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
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.archive_outlined),
            tooltip: l10n.sessionsArchive,
            onPressed:
                (sel.selectedIds.isEmpty ||
                        sel.isBatchDeleting)
                    ? null
                    : () => _confirmBatchArchive(
                        context, sel),
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
          onPressed:
              (sel.selectedIds.isEmpty ||
                      sel.isBatchDeleting)
                  ? null
                  : () => _confirmBatchDelete(
                      context, sel),
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
        SessionsListContent(
          selectionNotifier: _selectionNotifier,
          searchQuery: _searchController.text,
          onClearSearch: _clearSearch,
        ),
        const SettingsScreen(),
      ],
    );
  }

  // ── Selection helpers ─────────────────────────

  void _clearSearch() {
    _searchController.clear();
    setState(() => _isSearching = false);
  }

  Set<String> _allSelectableSessionIds() {
    final sessions =
        ref.read(sessionsNotifierProvider);
    return sessions.values.map((s) => s.id).toSet();
  }

  bool _hasActiveSessionsInSelection(
    SelectionState sel,
  ) {
    final sessions =
        ref.read(sessionsNotifierProvider);
    return sel.selectedIds.any((id) {
      final s = sessions[id];
      return s != null && isSessionActive(s);
    });
  }

  void _exitSelectionMode() {
    _selectionNotifier.value =
        const SelectionState();
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
    SelectionState sel,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sessions =
        ref.read(sessionsNotifierProvider);
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
          content: Text(
            dl10n.sessionsArchiveNConfirm(count),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: Text(dl10n.commonCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
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
        await SessionsApi()
            .setSessionArchived(id, true);
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
      ref
          .read(sessionsNotifierProvider.notifier)
          .loadFromSync();
    }

    _exitSelectionMode();

    if (failCount > 0 && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.sessionsArchivePartialFail(
                failCount),
          ),
        ),
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
          content: Text(
            dl10n.sessionsDeleteNConfirm(count),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: Text(dl10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () =>
                  Navigator.pop(ctx, true),
              child: Text(dl10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    _selectionNotifier.value =
        sel.copyWith(isBatchDeleting: true);

    final ids =
        List<String>.from(sel.selectedIds);

    final failCount = await ref
        .read(sessionsNotifierProvider.notifier)
        .optimisticBatchDelete(ids);

    _exitSelectionMode();

    if (failCount > 0 && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.sessionsDeletePartialFail(
                failCount),
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
