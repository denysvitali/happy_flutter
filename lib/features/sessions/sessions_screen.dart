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

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    if (_activeTab == AppTab.sessions) {
      return _buildSessionsAppBar(context, l10n);
    }
    return AppBar(
      title: Text(_getTabTitle(l10n)),
    );
  }

  AppBar _buildSessionsAppBar(BuildContext context, AppLocalizations l10n) {
    final connectionStatus = ref.watch(connectionNotifierProvider);

    return AppBar(
      title: Text(l10n.sessionHistoryTitle),
      actions: [
        ConnectionStatusBadge(status: connectionStatus),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _SessionsListContent.showNewSessionDialog(context),
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

/// Sessions list content widget
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsNotifierProvider);
    final sessionList = sessions.values.toList();

    // Mark as loaded once we get any data or sync is initialized
    if (sessionList.isNotEmpty || sync.isInitialized) {
      _hasLoaded = true;
    }

    final activeSessions = sessionList.where(isSessionActive).toList();
    final inactiveSessions =
        sessionList.where((s) => !isSessionActive(s)).toList();

    // Create localized date group headers
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

    return sessionList.isEmpty
        ? const EmptySessionsView()
        : RefreshIndicator(
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
            ),
          );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    String Function(DateGroup) localizeDateGroup,
  ) {
    // Group active sessions by path
    final activeByPath = <String, List<Session>>{};
    for (final s in activeSessions) {
      final path = s.metadata?.path ?? 'Unknown';
      activeByPath.putIfAbsent(path, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Active sessions grouped by path
        if (activeSessions.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.sessionActiveSessions),
          for (final entry in activeByPath.entries) ...[
            if (activeByPath.length > 1)
              _PathHeader(path: entry.key),
            for (final session in entry.value)
              ActiveSessionCard(
                session: session,
                onTap: () => context.push('/chat/${session.id}'),
              ),
          ],
        ],

        // Archived sessions as a flat section
        if (inactiveSessions.isNotEmpty) ...[
          _SectionHeader(
            title: '${context.l10n.sessionHistory}'
                ' (${inactiveSessions.length})',
          ),
          ..._buildArchivedItems(
            context,
            inactiveSessions,
            localizeDateGroup,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildArchivedItems(
    BuildContext context,
    List<Session> sessions,
    String Function(DateGroup) localizeDateGroup,
  ) {
    final groupedItems = groupSessionsByDate(
      sessions,
      localize: localizeDateGroup,
    );

    return groupedItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      switch (item) {
        case SessionHistoryDateHeader(:final date):
          return _DateHeaderWidget(date: date);
        case SessionHistorySession(:final session):
          final prevItem = index > 0 ? groupedItems[index - 1] : null;
          final nextItem = index < groupedItems.length - 1
              ? groupedItems[index + 1]
              : null;
          final isFirst = prevItem is SessionHistoryDateHeader;
          final isLast =
              nextItem is SessionHistoryDateHeader || nextItem == null;
          final isSingle = isFirst && isLast;
          return SessionCard(
            session: session,
            onTap: () => context.push('/chat/${session.id}'),
            isFirst: isFirst,
            isLast: isLast,
            isSingle: isSingle,
          );
      }
    }).toList();
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

/// Section header for active sessions.
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
/// Matches React Native's StatusDot component implementation.
class StatusDot extends StatefulWidget {
  final Color color;
  final bool isPulsing;
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
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
      _controller.animateTo(1.0, duration: const Duration(milliseconds: 200));
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
        // React Native pulsing: opacity goes from 1.0 to 0.3 and back
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

/// Active session card with green status indicator styling.
class ActiveSessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  const ActiveSessionCard({
    super.key,
    required this.session,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Active indicator badge
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Avatar with flavor icon
              SessionAvatar(
                id: avatarId,
                flavor: sessionFlavor,
                size: 48,
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
                    formatTimestamp(session.updatedAt, relative: true),
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
    );
  }

  Widget _buildStatusRow(BuildContext context, SessionStatus status) {
    final color = Color(status.statusColor);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status dot container (matches React Native styling)
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
/// Matches React Native's CompactSessionRow implementation.
class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool isSingle;
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

    // Determine card styling based on position
    BorderRadius? borderRadius;
    if (isSingle) {
      borderRadius = BorderRadius.circular(12);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
    }

    // Session title color based on connection status (matches React Native)
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
              // Avatar with flavor icon, monochrome when disconnected
              SessionAvatar(
                id: avatarId,
                flavor: sessionFlavor,
                size: 48,
                monochrome: !sessionStatus.isConnected,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session name with color based on connection status
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
                    // Session subtitle (path)
                    Text(
                      sessionSubtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    // Status row with thinking indicator
                    if (sessionStatus.shouldShowStatus)
                      _buildStatusRow(context, sessionStatus),
                  ],
                ),
              ),
              // Right side: timestamp and status indicator
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
          // Status dot container (matches React Native styling)
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

/// Empty sessions view.
class EmptySessionsView extends StatelessWidget {
  const EmptySessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.computer_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.sessionNoSessionsYet,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emptyMainScreenInstallCli,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emptyMainScreenRunIt,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emptyMainScreenScanQrCode,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _SessionsListContent.showNewSessionDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.sessionNewSession),
          ),
        ],
      ),
    );
  }
}

/// Connection status badge.
class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;

  const ConnectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.connecting => Colors.orange,
      ConnectionStatus.error => Colors.red,
      ConnectionStatus.disconnected => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.circle, size: 12, color: color),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = ref.watch(machinesNotifierProvider).values
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
                ...machines.map((machine) => DropdownMenuItem(
                      value: machine.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.computer, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              machine.metadata?.displayName ?? machine.metadata?.host ?? machine.id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
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
              final sessions =
                  ref.read(sessionsNotifierProvider);
              final paths = sessions.values
                  .where((s) =>
                      s.metadata?.machineId ==
                      _selectedMachine)
                  .map((s) => s.metadata?.path)
                  .whereType<String>()
                  .toSet()
                  .toList();
              if (textEditingValue.text.isEmpty) {
                return paths;
              }
              return paths.where((p) => p
                  .toLowerCase()
                  .contains(
                      textEditingValue.text.toLowerCase()));
            },
            onSelected: (value) {
              setState(() => _selectedPath = value);
            },
            fieldViewBuilder: (context, controller,
                focusNode, onFieldSubmitted) {
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
    final sessionId = await sync.createSession(machineId: machineId, path: path);
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
