import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/websocket_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_status.dart';
import '../../core/utils/session_utils.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import 'session_avatar.dart';

// ─── Stagger constants ───────────────────────────────────────────────────────
const _kStaggerStep = 30; // ms between each card
const _kSlideDuration = 250; // ms for slide+fade

/// Sessions list screen with date grouping and enhanced status display.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  AppTab _activeTab = AppTab.sessions;
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friendsState = ref.watch(friendsNotifierProvider);
    final feedState = ref.watch(feedNotifierProvider);
    final inboxBadgeCount = friendsState.incomingRequests.length;
    final showInboxDot = feedState.unreadCount > 0;

    return Scaffold(
      appBar: _buildAppBar(context, l10n),
      body: _buildCurrentTabContent(),
      bottomNavigationBar: TabBar(
        activeTab: _activeTab,
        onTabPress: (tab) => setState(() => _activeTab = tab),
        inboxBadgeCount: inboxBadgeCount,
        showInboxBadge: showInboxDot,
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
    return AppBar(
      title: Text(_getTabTitle(l10n)),
    );
  }

  AppBar _buildSessionsAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final connectionStatus = ref.watch(connectionNotifierProvider);

    return AppBar(
      title: Text(l10n.sessionHistoryTitle),
      actions: [
        ConnectionStatusBadge(status: connectionStatus),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () =>
              _SessionsListContent.showNewSessionDialog(context),
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
    switch (_activeTab) {
      case AppTab.inbox:
        return const InboxScreen();
      case AppTab.sessions:
        return const _SessionsListContent();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }
}

/// Sessions list content widget.
class _SessionsListContent extends ConsumerStatefulWidget {
  const _SessionsListContent();

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
  // Track list key to trigger stagger animation on first load.
  bool _animationTriggered = false;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final machines = ref.watch(machinesNotifierProvider);
    // Only watch the specific settings fields that affect session display to
    // avoid re-sorting on every unrelated settings change.
    final compactMode = ref.watch(
      settingsNotifierProvider.select((s) => s.compactSessionView),
    );
    final hideInactive = ref.watch(
      settingsNotifierProvider.select((s) => s.hideInactiveSessions),
    );
    final sessionList = sessions.values.toList();

    // Mark as loaded once we get any data or sync is initialized.
    if (sessionList.isNotEmpty || sync.isInitialized) {
      _hasLoaded = true;
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
        compactMode: settings.compactSessionView,
        hideInactive: settings.hideInactiveSessions,
        showFlavorIcons: settings.showFlavorIcons,
        avatarStyle: _parseAvatarStyle(settings.avatarStyle),
      ),
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    Map<String, Machine> machines, {
    required bool triggerStagger,
    required bool compactMode,
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
          child: _SectionHeader(
            title: context.l10n.sessionActiveSessions,
          ),
        ),
      );

      for (final entry in (activeByPath.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))) {
        children.add(
          _FadeInSection(
            delay: Duration(
              milliseconds: _kStaggerStep * staggerIndex,
            ),
            child: _PathHeader(path: entry.key),
          ),
        );
        for (final session in entry.value) {
          final capturedIndex = staggerIndex;
          final card = compactMode
              ? CompactActiveSessionCard(
                  session: session,
                  onTap: () => context.push('/chat/${session.id}'),
                  showFlavorIcon: showFlavorIcons,
                  avatarStyle: avatarStyle,
                )
              : ActiveSessionCard(
                  session: session,
                  onTap: () => context.push('/chat/${session.id}'),
                  showFlavorIcon: showFlavorIcons,
                  avatarStyle: avatarStyle,
                );
          children.add(
            _StaggeredSlideIn(
              index: capturedIndex,
              animate: triggerStagger,
              child: _DismissibleActiveSession(
                session: session,
                child: card,
              ),
            ),
          );
          staggerIndex++;
        }
      }
    }

    // Archived sessions section — hidden when hideInactive is true.
    if (inactiveSessions.isNotEmpty && !hideInactive) {
      children.add(
        _FadeInSection(
          delay: Duration(milliseconds: _kStaggerStep * staggerIndex),
          child: _SectionHeader(
            title: '${context.l10n.sessionHistory}'
                ' (${inactiveSessions.length})',
          ),
        ),
      );

      final archivedItems = _buildArchivedItems(
        context,
        inactiveSessions,
        machines,
        startIndex: staggerIndex,
        animate: triggerStagger,
        compactMode: compactMode,
        showFlavorIcons: showFlavorIcons,
        avatarStyle: avatarStyle,
      );
      children.addAll(archivedItems);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: children,
    );
  }

  List<Widget> _buildArchivedItems(
    BuildContext context,
    List<Session> sessions,
    Map<String, Machine> machines, {
    required int startIndex,
    required bool animate,
    required bool compactMode,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final folderItems = groupSessionsByFolder(sessions, machines);

    var itemIndex = startIndex;
    final widgets = <Widget>[];

    for (final item in folderItems) {
      switch (item) {
        case SessionFolderHeader(
          :final displayPath,
          :final machineName,
          :final sessionCount,
        ):
          widgets.add(
            _FadeInSection(
              delay: Duration(
                milliseconds: _kStaggerStep * itemIndex,
              ),
              child: _FolderSectionHeader(
                displayPath: displayPath,
                machineName: machineName,
                sessionCount: sessionCount,
              ),
            ),
          );
        case SessionFolderEntry(
          :final session,
          :final isFirst,
          :final isLast,
          :final isSingle,
        ):
          final capturedIndex = itemIndex;
          widgets.add(
            _StaggeredSlideIn(
              index: capturedIndex,
              animate: animate,
              child: _DismissibleInactiveSession(
                session: session,
                child: SessionCard(
                  session: session,
                  onTap: () => context.push('/chat/${session.id}'),
                  isFirst: isFirst,
                  isLast: isLast,
                  isSingle: isSingle,
                  compact: compactMode,
                  showFlavorIcon: showFlavorIcons,
                  avatarStyle: avatarStyle,
                ),
              ),
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
  const _DismissibleActiveSession({
    required this.session,
    required this.child,
  });

  final Session session;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('active-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmArchive(context, ref),
      // Keep item visible after dismiss (data refresh handles removal).
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Archive',
              style: TextStyle(
                color: Colors.white,
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

  Future<bool> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Session'),
        content: const Text(
          'This will stop the running session. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await sync.sessionRPC(session.id, 'killSession', {});
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive session: $e'),
          ),
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
    return Dismissible(
      key: ValueKey('inactive-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, ref),
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
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

  Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'This will permanently delete the session and all its messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final success = await sync.deleteSession(session.id);
      if (success) {
        await ref
            .read(sessionsNotifierProvider.notifier)
            .refreshFromSync();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete session: $e')),
        );
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
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.animate) {
      final delay =
          Duration(milliseconds: _kStaggerStep * widget.index);
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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
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
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
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
class _PathHeader extends StatelessWidget {
  const _PathHeader({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        path,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        overflow: TextOverflow.ellipsis,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}



/// Folder section header for grouping inactive sessions by directory + machine.
///
/// Shows the folder path (monospace) with the machine name on the right,
/// and a session count label. Styled more subdued than [_PathHeader] since
/// these are archived sessions.
class _FolderSectionHeader extends StatelessWidget {
  const _FolderSectionHeader({
    required this.displayPath,
    required this.machineName,
    required this.sessionCount,
  });

  /// The folder path to display (with ~ substitution).
  final String displayPath;

  /// The machine display name.
  final String machineName;

  /// Number of sessions in this folder group.
  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mutedColor = cs.onSurfaceVariant.withValues(alpha: 0.7);
    final badgeColor = cs.onSurfaceVariant.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayPath,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  machineName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sessionCount == 1
                ? '1 session'
                : '$sessionCount sessions',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status widgets ──────────────────────────────────────────────────────────



/// Status dot widget with pulsing animation.
///
/// Matches React Native's StatusDot component implementation.
class StatusDot extends StatefulWidget {
  const StatusDot({
    required this.color,
    super.key,
    this.isPulsing = false,
    this.size = 6,
  });

  /// The dot color.
  final Color color;

  /// Whether the dot should pulse continuously.
  final bool isPulsing;

  /// Diameter of the dot in logical pixels.
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // React Native pulsing: opacity goes from 1.0 to 0.3 and back.
        final opacity =
            widget.isPulsing ? 0.3 + 0.7 * _animation.value : 1.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// ─── Badge helpers ───────────────────────────────────────────────────────────

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
        width: 16,
        height: 16,
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
  const _TodoProgressBadge({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 10,
            color: cs.onSurfaceVariant,
          ),
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
  final completed =
      todos.where((t) => t.status == TodoState.completed).length;
  if (completed >= total) return null;
  return (completed: completed, total: total);
}

// ─── Active session card ─────────────────────────────────────────────────────

/// Active session card with a gradient border and primary-tinted background.
class ActiveSessionCard extends StatefulWidget {
  const ActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  @override
  State<ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<ActiveSessionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(widget.session);
    final avatarId = getSessionAvatarId(widget.session);
    final sessionName = getSessionName(widget.session);
    final sessionSubtitle = getSessionSubtitle(widget.session);
    final sessionFlavor = widget.session.metadata?.flavor;
    final hasDraft = widget.session.draft != null &&
        widget.session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(widget.session.todos);

    return AnimatedBuilder(
      animation: _glowAnimation,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  color: Color(sessionStatus.statusDotColor),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with Hero + optional draft badge.
                        Hero(
                          tag: 'session-avatar-${widget.session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 48,
                                showFlavorIcon:
                                    widget.showFlavorIcon,
                                style: widget.avatarStyle,
                              ),
                              if (hasDraft) const _DraftBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sessionName,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                sessionSubtitle,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                widget.session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            StatusDot(
                              color: Color(sessionStatus.statusDotColor),
                              isPulsing: sessionStatus.isPulsing,
                              size: 8,
                            ),
                            if (todoProgress != null) ...[
                              const SizedBox(height: 4),
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
      builder: (context, child) {
        final t = _glowAnimation.value;
        final glowOpacity = 0.04 + 0.08 * t;
        final borderOpacity = 0.20 + 0.20 * t;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cs.primary.withValues(alpha: 0.04),
            border: Border.all(
              color: cs.primary.withValues(alpha: borderOpacity),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: glowOpacity),
                blurRadius: 6 * t + 2,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
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
  });

  /// The session to display.
  final Session session;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(session.todos);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.primary.withValues(alpha: 0.04),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  color: Color(sessionStatus.statusDotColor),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        const SizedBox(width: 10),
                        Expanded(
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
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                session.updatedAt,
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
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
    this.compact = false,
    this.avatarStyle,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Whether this is the first card in a group.
  final bool isFirst;

  /// Whether this is the last card in a group.
  final bool isLast;

  /// Whether this is the only card in a group.
  final bool isSingle;

  /// Whether to show a date header above the card.
  final bool showDateHeader;

  /// Whether to use compact layout (smaller avatar, reduced padding).
  final bool compact;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(session.todos);

    // Determine card border-radius based on position within group.
    BorderRadius borderRadius;
    if (isSingle) {
      borderRadius = BorderRadius.circular(12);
    } else if (isFirst) {
      borderRadius =
          const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      borderRadius =
          const BorderRadius.vertical(bottom: Radius.circular(12));
    } else {
      borderRadius = BorderRadius.zero;
    }

    // Session title color based on connection status (matches RN).
    final titleColor = sessionStatus.isConnected
        ? cs.onSurface
        : cs.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide.none,
      ),
      elevation: 0,
      color: cs.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: sessionStatus.isConnected
                    ? Color(sessionStatus.statusDotColor)
                    : const Color(0xFF999999),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 6 : 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with Hero animation, monochrome when
                      // disconnected, and optional draft badge.
                      Hero(
                        tag: 'session-avatar-${session.id}',
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SessionAvatar(
                              id: avatarId,
                              flavor: sessionFlavor,
                              size: compact ? 36 : 44,
                              monochrome: !sessionStatus.isConnected,
                              showFlavorIcon: showFlavorIcon,
                              style: avatarStyle,
                            ),
                            if (hasDraft) const _DraftBadge(),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sessionSubtitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: timestamp, status dot, optional todo.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatTimestamp(
                              session.updatedAt,
                              relative: true,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StatusDot(
                            color: sessionStatus.isConnected
                                ? Color(sessionStatus.statusDotColor)
                                : const Color(0xFF999999),
                            isPulsing: sessionStatus.isPulsing,
                            size: 7,
                          ),
                          if (todoProgress != null) ...[
                            const SizedBox(height: 4),
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
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

/// Empty sessions view with an animated computer icon and CTA button.
class EmptySessionsView extends StatefulWidget {
  const EmptySessionsView({super.key});

  @override
  State<EmptySessionsView> createState() => _EmptySessionsViewState();
}

class _EmptySessionsViewState extends State<EmptySessionsView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    // Pulse: scale icon between 0.92 and 1.08.
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Icon glow opacity: 0.0 to 0.6.
    _glow = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final iconColor = cs.onSurfaceVariant.withValues(alpha: 0.4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulse.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Soft glow halo behind the icon.
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(
                                alpha: _glow.value * 0.35,
                              ),
                              blurRadius: 32,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.computer_outlined,
                        size: 64,
                        color: iconColor,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              l10n.sessionNoSessionsYet,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyMainScreenInstallCli,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.emptyMainScreenRunIt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.emptyMainScreenScanQrCode,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () =>
                  _SessionsListContent.showNewSessionDialog(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.sessionNewSession),
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
  State<ConnectionStatusBadge> createState() =>
      _ConnectionStatusBadgeState();
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
    final color = switch (widget.status) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.connecting => Colors.orange,
      ConnectionStatus.error => Colors.red,
      ConnectionStatus.disconnected => Colors.grey,
    };

    final isConnecting =
        widget.status == ConnectionStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: isConnecting
            ? AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final opacity =
                      0.35 + 0.65 * _pulseAnimation.value;
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
  ConsumerState<NewSessionDialog> createState() =>
      _NewSessionDialogState();
}

class _NewSessionDialogState extends ConsumerState<NewSessionDialog> {
  String? _selectedPath;
  String? _selectedMachine;
  bool _isCreating = false;
  String? _createError;
  String _selectedAgent = 'claude';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              decoration:
                  InputDecoration(labelText: l10n.sessionMachine),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (_selectedMachine == null) return const [];
              final sessions = ref.read(sessionsNotifierProvider);
              final paths = sessions.values
                  .where(
                    (s) =>
                        s.metadata?.machineId == _selectedMachine,
                  )
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
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
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
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'claude',
                label: Text('Claude'),
              ),
              ButtonSegment(
                value: 'codex',
                label: Text('Codex'),
              ),
              ButtonSegment(
                value: 'gemini',
                label: Text('Gemini'),
              ),
            ],
            selected: {_selectedAgent},
            onSelectionChanged: (selection) {
              setState(() => _selectedAgent = selection.first);
            },
          ),
          if (_createError != null) ...[
            const SizedBox(height: 12),
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
          onPressed: !_isCreating &&
                  (_selectedPath?.isNotEmpty ?? false) &&
                  _selectedMachine != null
              ? () => _createSession(context)
              : null,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
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
      final sessionId = await sync.createSession(
        machineId: machineId,
        path: path,
      );
      if (!mounted) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      navigator.pop();
      unawaited(router.push('/chat/$sessionId'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }
}
