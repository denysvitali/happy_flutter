import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/api/websocket_client.dart';
import '../../core/ui/tab_bar/tab_bar.dart';
import '../../core/utils/session_utils.dart';
import '../../core/utils/session_status.dart';
import '../../core/ui/avatars/avatar.dart';
import '../../core/ui/avatars/avatar_gradient.dart';
import '../../core/ui/avatars/avatar_pixelated.dart';
import '../../core/ui/avatars/avatar_brutalist.dart';
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
  int _inboxBadgeCount = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: _buildAppBar(context, l10n),
      body: _buildCurrentTabContent(),
      bottomNavigationBar: TabBar(
        activeTab: _activeTab,
        onTabPress: (tab) => setState(() => _activeTab = tab),
        inboxBadgeCount: _inboxBadgeCount,
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
class _SessionsListContent extends ConsumerWidget {
  const _SessionsListContent();

  static void showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NewSessionDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final sessionList = sessions.values.toList();
    final activeSessions = sessionList.where(isSessionActive).toList();
    final inactiveSessions =
        sessionList.where((s) => !isSessionActive(s)).toList();

    return sessionList.isEmpty
        ? const EmptySessionsView()
        : RefreshIndicator(
            onRefresh: () => _refreshSessions(ref),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _calculateItemCount(activeSessions, inactiveSessions),
              itemBuilder: (context, index) {
                return _buildListItem(
                  context,
                  ref,
                  index,
                  activeSessions,
                  inactiveSessions,
                );
              },
            ),
          );
  }

  Future<void> _refreshSessions(WidgetRef ref) async {
  }

  int _calculateItemCount(
    List<Session> activeSessions,
    List<Session> inactiveSessions,
  ) {
    int count = 0;
    if (activeSessions.isNotEmpty) {
      count += 1;
      count += activeSessions.length;
    }
    if (inactiveSessions.isNotEmpty) {
      final groupedItems = groupSessionsByDate(inactiveSessions);
      count += groupedItems.length;
    }
    return count;
  }

  Widget _buildListItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
  ) {
    int currentIndex = 0;

    if (activeSessions.isNotEmpty) {
      if (index == 0) {
        return _SectionHeader(title: context.l10n.sessionActiveSessions);
      }
      currentIndex = 1;
      if (index < 1 + activeSessions.length) {
        final sessionIndex = index - currentIndex;
        return SessionCard(
          session: activeSessions[sessionIndex],
          showDateHeader: false,
        );
      }
      currentIndex += activeSessions.length;
    }

    final groupedItems = groupSessionsByDate(inactiveSessions);
    if (index >= currentIndex && index < currentIndex + groupedItems.length) {
      final itemIndex = index - currentIndex;
      final item = groupedItems[itemIndex];
      return _buildGroupedItem(context, item, groupedItems, itemIndex);
    }

    return const SizedBox.shrink();
  }

  Widget _buildGroupedItem(
    BuildContext context,
    SessionHistoryItem item,
    List<SessionHistoryItem> allItems,
    int index,
  ) {
    switch (item) {
      case SessionHistoryDateHeader(:final date):
        return _DateHeaderWidget(date: date);
      case SessionHistorySession(:final session):
        final prevItem = index > 0 ? allItems[index - 1] : null;
        final nextItem =
            index < allItems.length - 1 ? allItems[index + 1] : null;
        final isFirst = prevItem is SessionHistoryDateHeader;
        final isLast = nextItem is SessionHistoryDateHeader || nextItem == null;
        final isSingle = isFirst && isLast;
        return SessionCard(
          session: session,
          isFirst: isFirst,
          isLast: isLast,
          isSingle: isSingle,
        );
    }
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

/// Session card widget with enhanced status display and avatars.
class SessionCard extends StatelessWidget {
  final Session session;
  final bool isFirst;
  final bool isLast;
  final bool isSingle;
  final bool showDateHeader;

  const SessionCard({
    super.key,
    required this.session,
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

    // Determine card styling based on position
    BorderRadius? borderRadius;
    if (isSingle) {
      borderRadius = BorderRadius.circular(12);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.zero,
        side: BorderSide.none,
      ),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () {
          // Navigate to chat screen
        },
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with style based on ID
              SessionAvatar(avatarId: avatarId, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session name
                    Text(
                      sessionName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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
    final theme = Theme.of(context);
    final color = Color(status.statusColor);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (status.isPulsing)
            SizedBox(
              width: 14,
              height: 14,
              child: _PulsingDot(color: color),
            )
          else
            Icon(
              Icons.circle,
              size: 8,
              color: color,
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status.statusText,
              style: TextStyle(
                color: color,
                fontSize: 12,
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

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: status.isConnected ? color : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Avatar widget for sessions that cycles through different styles.
class SessionAvatar extends StatelessWidget {
  final String avatarId;
  final double size;

  const SessionAvatar({
    super.key,
    required this.avatarId,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    // Use avatar ID hash to determine style
    final styleIndex = _hashCode(avatarId) % 3;

    return switch (styleIndex) {
      0 => AvatarGradient(id: avatarId, size: size),
      1 => AvatarPixelated(id: avatarId, size: size),
      _ => AvatarBrutalist(id: avatarId, size: size),
    };
  }

  int _hashCode(String str) {
    var hash = 0;
    for (final char in str.runes) {
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.abs();
  }
}

/// Pulsing dot animation for thinking/permission states.
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
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
        return Transform.scale(
          scale: 0.5 + _animation.value * 0.5,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(1 - _animation.value * 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = ref.watch(machinesNotifierProvider).values.toList();
    
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
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.sessionSelectMachine),
                ),
                ...machines.map((machine) => DropdownMenuItem(
                      value: machine.id,
                      child: Text(machine.metadata?.displayName ?? machine.id),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMachine = value;
                });
              },
            ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: l10n.sessionPath,
              hintText: l10n.sessionPathHint,
            ),
            onChanged: (value) {
              setState(() {
                _selectedPath = value;
              });
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
          onPressed: _selectedPath != null && _selectedMachine != null 
              ? () => _createSession(context) 
              : null,
          child: Text(l10n.commonCreate),
        ),
      ],
    );
  }

  void _createSession(BuildContext context) {
    // Implement session creation
    Navigator.pop(context);
  }
}
