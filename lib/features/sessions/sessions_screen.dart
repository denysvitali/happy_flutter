import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/websocket_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
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
  Timer? _syncSnapshotTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      await ref.read(friendsNotifierProvider.notifier).refreshFromSync();
      await ref.read(feedNotifierProvider.notifier).refreshFromSync();
    });
    _syncSnapshotTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) {
        ref.read(sessionsNotifierProvider.notifier).loadFromSync();
        ref.read(friendsNotifierProvider.notifier).loadFromSync();
        ref.read(feedNotifierProvider.notifier).loadFromSync();
      },
    );
  }

  @override
  void dispose() {
    _syncSnapshotTimer?.cancel();
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
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsNotifierProvider);
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

    // Create localized date group headers.
    String localizeDateGroup(DateGroup group) {
      return switch (group) {
        DateGroup.today => l10n.dateGroupToday,
        DateGroup.yesterday => l10n.dateGroupYesterday,
        DateGroup.lastSevenDays => l10n.dateGroupLastSevenDays,
        DateGroup.older => l10n.dateGroupOlder,
      };
    }

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
        localizeDateGroup,
        triggerStagger: triggerStagger,
      ),
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    String Function(DateGroup) localizeDateGroup, {
    required bool triggerStagger,
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
        if (activeByPath.length > 1) {
          children.add(
            _FadeInSection(
              delay: Duration(
                milliseconds: _kStaggerStep * staggerIndex,
              ),
              child: _PathHeader(path: entry.key),
            ),
          );
        }
        for (final session in entry.value) {
          final capturedIndex = staggerIndex;
          children.add(
            _StaggeredSlideIn(
              index: capturedIndex,
              animate: triggerStagger,
              child: ActiveSessionCard(
                session: session,
                onTap: () => context.push('/chat/${session.id}'),
              ),
            ),
          );
          staggerIndex++;
        }
      }
    }

    // Archived sessions section.
    if (inactiveSessions.isNotEmpty) {
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
        localizeDateGroup,
        startIndex: staggerIndex,
        animate: triggerStagger,
      );
      children.addAll(archivedItems);
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: children,
    );
  }

  List<Widget> _buildArchivedItems(
    BuildContext context,
    List<Session> sessions,
    String Function(DateGroup) localizeDateGroup, {
    required int startIndex,
    required bool animate,
  }) {
    final groupedItems = groupSessionsByDate(
      sessions,
      localize: localizeDateGroup,
    );

    var itemIndex = startIndex;
    final widgets = <Widget>[];

    for (var i = 0; i < groupedItems.length; i++) {
      final item = groupedItems[i];
      switch (item) {
        case SessionHistoryDateHeader(:final date):
          widgets.add(
            _FadeInSection(
              delay: Duration(
                milliseconds: _kStaggerStep * itemIndex,
              ),
              child: _DateSectionHeader(date: date),
            ),
          );
        case SessionHistorySession(:final session):
          final prevItem = i > 0 ? groupedItems[i - 1] : null;
          final nextItem =
              i < groupedItems.length - 1 ? groupedItems[i + 1] : null;
          final isFirst = prevItem is SessionHistoryDateHeader;
          final isLast =
              nextItem is SessionHistoryDateHeader || nextItem == null;
          final isSingle = isFirst && isLast;
          final capturedIndex = itemIndex;
          widgets.add(
            _StaggeredSlideIn(
              index: capturedIndex,
              animate: animate,
              child: SessionCard(
                session: session,
                onTap: () => context.push('/chat/${session.id}'),
                isFirst: isFirst,
                isLast: isLast,
                isSingle: isSingle,
              ),
            ),
          );
          itemIndex++;
      }
    }

    return widgets;
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

/// iOS-style date section header — small-caps label + extending divider.
class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.colorScheme.primary;
    final dividerColor =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            date.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dividerColor, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status widgets ──────────────────────────────────────────────────────────

/// Pill-shaped status badge used inside session cards.
///
/// Shows a dot + text in a rounded container with a tinted background.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.color,
    required this.text,
    required this.isPulsing,
  });
  final Color color;
  final String text;
  final bool isPulsing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: color, isPulsing: isPulsing, size: 6),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

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

// ─── Active session card ─────────────────────────────────────────────────────

/// Active session card with a gradient border and primary-tinted background.
class ActiveSessionCard extends StatefulWidget {
  const ActiveSessionCard({
    required this.session,
    super.key,
    this.onTap,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

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

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final t = _glowAnimation.value;
        final glowOpacity = 0.10 + 0.30 * t;
        final borderOpacity = 0.30 + 0.40 * t;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // Subtle primary-tinted background overlay.
            color: cs.surface,
            // Gradient border via a gradient BoxDecoration trick:
            // outer container has gradient, inner has surface color.
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: glowOpacity),
                blurRadius: 14 * t + 4,
                spreadRadius: 2 * t,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.primary.withValues(alpha: 0.04),
              border: Border.all(
                color: cs.primary.withValues(alpha: borderOpacity),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Pulsing green active indicator.
                      _ActiveIndicatorDot(t: t, primary: cs.primary),
                      const SizedBox(width: 12),
                      // Avatar with Hero animation.
                      Hero(
                        tag: 'session-avatar-${widget.session.id}',
                        child: SessionAvatar(
                          id: avatarId,
                          flavor: sessionFlavor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionName,
                              style:
                                  theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              sessionSubtitle,
                              style:
                                  theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (sessionStatus.shouldShowStatus) ...[
                              const SizedBox(height: 8),
                              _StatusPill(
                                color: Color(sessionStatus.statusColor),
                                text: sessionStatus.statusText,
                                isPulsing: sessionStatus.isPulsing,
                              ),
                            ],
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small pulsing dot shown on the left of the active session card.
class _ActiveIndicatorDot extends StatelessWidget {
  const _ActiveIndicatorDot({required this.t, required this.primary});
  final double t;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.35 + 0.30 * t),
            blurRadius: 6 + 4 * t,
            spreadRadius: 1,
          ),
        ],
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
    super.key,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Hero animation, monochrome when disconnected.
              Hero(
                tag: 'session-avatar-${session.id}',
                child: SessionAvatar(
                  id: avatarId,
                  flavor: sessionFlavor,
                  size: 44,
                  monochrome: !sessionStatus.isConnected,
                ),
              ),
              const SizedBox(width: 14),
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
                    if (sessionStatus.shouldShowStatus) ...[
                      const SizedBox(height: 6),
                      _StatusPill(
                        color: Color(sessionStatus.statusColor),
                        text: sessionStatus.statusText,
                        isPulsing: sessionStatus.isPulsing,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side: timestamp and status dot.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTimestamp(session.updatedAt, relative: true),
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
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                  setState(() => _selectedPath = value);
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: !_isCreating &&
                  _selectedPath != null &&
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
    if (machineId == null || path == null || path.isEmpty) {
      return;
    }

    // Capture context-dependent objects before async gap
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);

    setState(() => _isCreating = true);
    final sessionId = await sync.createSession(
      machineId: machineId,
      path: path,
    );
    if (!mounted) {
      return;
    }

    if (sessionId == null || sessionId.isEmpty) {
      setState(() => _isCreating = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to start session')),
      );
      return;
    }

    ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    navigator.pop();
    unawaited(router.push('/chat/$sessionId'));
  }
}
