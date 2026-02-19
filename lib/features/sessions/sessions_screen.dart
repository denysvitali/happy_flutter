import 'dart:async';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/api/websocket_client.dart';
import '../../core/services/sync_service.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_utils.dart';
import '../../core/utils/session_status.dart';
import 'session_avatar.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';

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

class _SessionsListContentState extends ConsumerState<_SessionsListContent> {
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
    final bool triggerStagger = !_animationTriggered;
    if (!_animationTriggered) {
      _animationTriggered = true;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(sessionsNotifierProvider.notifier)
            .refreshFromSync();
      },
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
    int staggerIndex = 0;

    final children = <Widget>[];

    // Active sessions section.
    if (activeSessions.isNotEmpty) {
      children.add(
        _FadeInSection(
          delay: Duration(milliseconds: 50 * staggerIndex),
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
              delay: Duration(milliseconds: 50 * staggerIndex),
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
          delay: Duration(milliseconds: 50 * staggerIndex),
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

    int itemIndex = startIndex;
    final widgets = <Widget>[];

    for (int i = 0; i < groupedItems.length; i++) {
      final item = groupedItems[i];
      switch (item) {
        case SessionHistoryDateHeader(:final date):
          widgets.add(
            _FadeInSection(
              delay: Duration(milliseconds: 50 * itemIndex),
              child: _DateHeaderWidget(date: date),
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

/// Staggered slide-in animation wrapper.
///
/// Each card slides up from 24px below its final position, with an
/// opacity fade, delayed by [index] * 50ms.
class _StaggeredSlideIn extends StatefulWidget {
  final int index;
  final bool animate;
  final Widget child;

  const _StaggeredSlideIn({
    required this.index,
    required this.animate,
    required this.child,
  });

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
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.animate) {
      final delay = Duration(milliseconds: 50 * widget.index);
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
  final Duration delay;
  final Widget child;

  const _FadeInSection({required this.delay, required this.child});

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

/// Path header for grouping sessions.
class _PathHeader extends StatelessWidget {
  final String path;
  const _PathHeader({required this.path});

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
  final String title;

  const _SectionHeader({required this.title});

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

/// Date header widget for grouped sessions.
class _DateHeaderWidget extends StatelessWidget {
  final String date;

  const _DateHeaderWidget({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      color: theme.colorScheme.surface,
      child: Text(
        date.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Status dot widget with pulsing animation.
///
/// Matches React Native's StatusDot component implementation.
class StatusDot extends StatefulWidget {
  /// The dot color.
  final Color color;

  /// Whether the dot should pulse continuously.
  final bool isPulsing;

  /// Diameter of the dot in logical pixels.
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    this.isPulsing = false,
    this.size = 6,
  });

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
        final opacity = widget.isPulsing
            ? 0.3 + 0.7 * _animation.value
            : 1.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Active session card with a pulsing green glow border.
class ActiveSessionCard extends StatefulWidget {
  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const ActiveSessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

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
    final sessionStatus = getSessionStatus(widget.session);
    final avatarId = getSessionAvatarId(widget.session);
    final sessionName = getSessionName(widget.session);
    final sessionSubtitle = getSessionSubtitle(widget.session);
    final sessionFlavor = widget.session.metadata?.flavor;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        // Pulsing glow: blur 4–18px, spread 0–3px, opacity 0.15–0.55.
        final t = _glowAnimation.value;
        final blurRadius = 4.0 + 14.0 * t;
        final spreadRadius = 0.0 + 3.0 * t;
        final glowOpacity = 0.15 + 0.40 * t;
        final borderOpacity = 0.25 + 0.35 * t;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.green.withOpacity(borderOpacity),
              width: 1.5,
            ),
          ),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(glowOpacity),
                  blurRadius: blurRadius,
                  spreadRadius: spreadRadius,
                ),
              ],
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Active indicator badge.
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(
                              0.4 + 0.3 * t,
                            ),
                            blurRadius: 6 + 4 * t,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sessionName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sessionSubtitle,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (sessionStatus.shouldShowStatus)
                            _buildStatusRow(context, sessionStatus),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatTimestamp(
                            widget.session.updatedAt,
                            relative: true,
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusIndicator(sessionStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(BuildContext context, SessionStatus status) {
    final color = Color(status.statusColor);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Center(
              child: StatusDot(
                color: color,
                isPulsing: status.isPulsing,
                size: 8,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status.statusText,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(SessionStatus status) {
    final color = Color(status.statusDotColor);

    return StatusDot(
      color: status.isConnected ? color : const Color(0xFF999999),
      isPulsing: status.isPulsing,
      size: 8,
    );
  }
}

/// Session card widget with enhanced status display and avatars.
///
/// Matches React Native's CompactSessionRow implementation.
class SessionCard extends StatelessWidget {
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

  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;

    // Determine card styling based on position.
    BorderRadius? borderRadius;
    if (isSingle) {
      borderRadius = BorderRadius.circular(12);
    } else if (isFirst) {
      borderRadius =
          const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      borderRadius =
          const BorderRadius.vertical(bottom: Radius.circular(12));
    }

    // Session title color based on connection status (matches RN).
    final titleColor = sessionStatus.isConnected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.zero,
        side: BorderSide.none,
      ),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Hero animation, monochrome when disconnected.
              Hero(
                tag: 'session-avatar-${session.id}',
                child: SessionAvatar(
                  id: avatarId,
                  flavor: sessionFlavor,
                  size: 48,
                  monochrome: !sessionStatus.isConnected,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sessionSubtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (sessionStatus.shouldShowStatus)
                      _buildStatusRow(context, sessionStatus),
                  ],
                ),
              ),
              // Right side: timestamp and status indicator.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTimestamp(session.updatedAt, relative: true),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusIndicator(sessionStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, SessionStatus status) {
    final color = Color(status.statusColor);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Center(
              child: StatusDot(
                color: color,
                isPulsing: status.isPulsing,
                size: 8,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status.statusText,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(SessionStatus status) {
    final color = Color(status.statusDotColor);

    return StatusDot(
      color: status.isConnected ? color : const Color(0xFF999999),
      isPulsing: status.isPulsing,
      size: 8,
    );
  }
}

/// Empty sessions view with an animated computer icon.
class EmptySessionsView extends StatefulWidget {
  const EmptySessionsView({super.key});

  @override
  State<EmptySessionsView> createState() => _EmptySessionsViewState();
}

class _EmptySessionsViewState extends State<EmptySessionsView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _fadeIn;

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
    _fadeIn = Tween<double>(begin: 0.0, end: 0.6).animate(
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
    final iconColor =
        theme.colorScheme.onSurfaceVariant.withOpacity(0.4);
    final glowColor = theme.colorScheme.primary;

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
                              color: glowColor
                                  .withOpacity(_fadeIn.value * 0.35),
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
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyMainScreenInstallCli,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.emptyMainScreenRunIt,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.emptyMainScreenScanQrCode,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
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

/// Connection status badge in the app bar.
///
/// Shows a pulsing indicator while connecting.
class ConnectionStatusBadge extends StatefulWidget {
  /// The current connection status.
  final ConnectionStatus status;

  const ConnectionStatusBadge({super.key, required this.status});

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
                  final opacity = 0.35 + 0.65 * _pulseAnimation.value;
                  final scale = 0.75 + 0.5 * _pulseAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: color.withOpacity(opacity),
                    ),
                  );
                },
              )
            : Icon(Icons.circle, size: 12, color: color),
      ),
    );
  }
}

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
              value: _selectedMachine,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start session')),
      );
      return;
    }

    ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    Navigator.pop(context);
    context.push('/chat/$sessionId');
  }
}
