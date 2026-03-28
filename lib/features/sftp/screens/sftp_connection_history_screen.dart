import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_empty_state.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Connection event type
enum ConnectionEventType {
  connect,
  disconnect,
  authSuccess,
  authFailure,
  sessionStart,
  sessionEnd,
}

/// A single connection event
class ConnectionEvent {
  const ConnectionEvent({
    required this.timestamp,
    required this.deviceId,
    required this.deviceName,
    required this.eventType,
    required this.username,
    this.ipAddress,
    this.duration,
    this.reason,
    this.bytesTransferred,
  });

  factory ConnectionEvent.fromJson(Map<String, dynamic> json) {
    return ConnectionEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      eventType: ConnectionEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => ConnectionEventType.connect,
      ),
      username: json['username'] as String,
      ipAddress: json['ipAddress'] as String?,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      reason: json['reason'] as String?,
      bytesTransferred: json['bytesTransferred'] as int?,
    );
  }

  final DateTime timestamp;
  final String deviceId;
  final String deviceName;
  final ConnectionEventType eventType;
  final String username;
  final String? ipAddress;
  final Duration? duration;
  final String? reason;
  final int? bytesTransferred;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'eventType': eventType.name,
      'username': username,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (duration != null) 'duration': duration!.inSeconds,
      if (reason != null) 'reason': reason,
      if (bytesTransferred != null)
        'bytesTransferred': bytesTransferred,
    };
  }
}

/// Connection history store with local persistence
class ConnectionHistoryStore {
  static const int _maxEvents = 5000;

  List<ConnectionEvent> _events = [];
  bool _initialized = false;

  Future<File> get _historyFile async {
    final appDir = await getApplicationSupportDirectory();
    return File('${appDir.path}/sftp_connection_history.json');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final file = await _historyFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List;
        _events = jsonList
            .map(
              (j) => ConnectionEvent.fromJson(
                j as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (_) {
      // Start fresh on error
      _events = [];
    }
  }

  Future<void> addEvent(ConnectionEvent event) async {
    _events.insert(0, event);

    if (_events.length > _maxEvents) {
      _events = _events.sublist(0, _maxEvents);
    }

    await _save();
  }

  List<ConnectionEvent> getEvents({
    String? deviceId,
    String? username,
    ConnectionEventType? eventType,
    int limit = 100,
  }) {
    var events = _events;

    if (deviceId != null) {
      events = events.where((e) => e.deviceId == deviceId).toList();
    }
    if (username != null) {
      events = events.where((e) => e.username == username).toList();
    }
    if (eventType != null) {
      events = events.where((e) => e.eventType == eventType).toList();
    }

    return events.take(limit).toList();
  }

  List<String> get allUsernames {
    return _events.map((e) => e.username).toSet().toList()..sort();
  }

  List<String> get allDeviceIds {
    return _events.map((e) => e.deviceId).toSet().toList()..sort();
  }

  Future<void> clear() async {
    _events = [];
    await _save();
  }

  /// Get connection stats for a device
  Map<String, dynamic> getDeviceStats(String deviceId) {
    final deviceEvents =
        _events.where((e) => e.deviceId == deviceId).toList();

    final connects = deviceEvents
        .where((e) => e.eventType == ConnectionEventType.connect)
        .length;
    final disconnects = deviceEvents
        .where((e) => e.eventType == ConnectionEventType.disconnect)
        .length;
    final authFailures = deviceEvents
        .where((e) => e.eventType == ConnectionEventType.authFailure)
        .length;

    final sessions = deviceEvents
        .where((e) => e.eventType == ConnectionEventType.sessionEnd)
        .where((e) => e.duration != null)
        .toList();

    var totalDuration = Duration.zero;
    for (final s in sessions) {
      totalDuration += s.duration!;
    }

    final avgDuration = sessions.isNotEmpty
        ? Duration(
            milliseconds:
                totalDuration.inMilliseconds ~/ sessions.length,
          )
        : Duration.zero;

    return {
      'totalConnections': connects,
      'totalDisconnections': disconnects,
      'authFailures': authFailures,
      'totalSessions': sessions.length,
      'totalDuration': totalDuration,
      'avgDuration': avgDuration,
      'uniqueUsers':
          deviceEvents.map((e) => e.username).toSet().length,
    };
  }

  Future<void> _save() async {
    try {
      final file = await _historyFile;
      final jsonList = _events.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Silently fail on save errors
    }
  }
}

/// Global singleton
final connectionHistoryStore = ConnectionHistoryStore();

/// Screen for viewing SFTP connection history
class SftpConnectionHistoryScreen extends StatefulWidget {
  const SftpConnectionHistoryScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<SftpConnectionHistoryScreen> createState() =>
      _SftpConnectionHistoryScreenState();
}

class _SftpConnectionHistoryScreenState
    extends State<SftpConnectionHistoryScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedDeviceId;
  String? _selectedUsername;
  ConnectionEventType? _eventTypeFilter;
  List<ConnectionEvent> _events = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDeviceId = widget.deviceId;
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    await connectionHistoryStore.initialize();
    if (!mounted) return;

    setState(() {
      _events = connectionHistoryStore.getEvents(
        deviceId: _selectedDeviceId,
        username: _selectedUsername,
        eventType: _eventTypeFilter,
      );
    });
  }

  Future<void> _exportHistory() async {
    if (_events.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No events to export')),
        );
      }
      return;
    }

    final jsonStr = jsonEncode(
      _events.map((e) => e.toJson()).toList(),
    );
    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_events.length} events copied to clipboard',
          ),
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Clear all connection history?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await connectionHistoryStore.clear();
      unawaited(_loadEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDevices = connectionHistoryStore.allDeviceIds;
    final allUsers = connectionHistoryStore.allUsernames;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed:
                _events.isNotEmpty ? _exportHistory : null,
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed:
                _events.isNotEmpty ? _clearHistory : null,
            tooltip: 'Clear history',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            AppTouchTarget.comfortable,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'History'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(allDevices, allUsers),
          _buildAnalyticsTab(allDevices),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    List<String> allDevices,
    List<String> allUsers,
  ) {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          child: Column(
            children: [
              Row(
                children: [
                  // Device filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedDeviceId,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Device',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.sm,
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        ...allDevices.map(
                          (id) => DropdownMenuItem(
                            value: id,
                            child: Text(
                              id,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDeviceId = value;
                        });
                        _loadEvents();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // User filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedUsername,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'User',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.sm,
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        ...allUsers.map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedUsername = value;
                        });
                        _loadEvents();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Event type filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _EventTypeChip(
                      label: 'All',
                      isSelected: _eventTypeFilter == null,
                      onTap: () {
                        setState(
                          () => _eventTypeFilter = null,
                        );
                        _loadEvents();
                      },
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ...ConnectionEventType.values.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.xs,
                        ),
                        child: _EventTypeChip(
                          label: _getEventTypeLabel(type),
                          isSelected:
                              _eventTypeFilter == type,
                          color: _getEventTypeColor(
                            type,
                            context,
                          ),
                          onTap: () {
                            setState(
                              () =>
                                  _eventTypeFilter = type,
                            );
                            _loadEvents();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Event count
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerLow,
          child: Row(
            children: [
              Text(
                '${_events.length} events',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'Max: 5,000',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        // Event list
        Expanded(
          child: _events.isEmpty
              ? AppEmptyState(
                  icon: Icons.history,
                  title: 'No connection history',
                  subtitle: 'Connection events will '
                      'appear here',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: _events.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(
                    height: AppSpacing.sm,
                  ),
                  itemBuilder: (context, index) {
                    return _ConnectionEventCard(
                      event: _events[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab(List<String> allDevices) {
    if (allDevices.isEmpty) {
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No data available',
        subtitle:
            'Analytics will appear after connections',
      );
    }

    return ListView.separated(
      padding: AppScreenPadding.standard,
      itemCount: allDevices.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final deviceId = allDevices[index];
        final stats =
            connectionHistoryStore.getDeviceStats(deviceId);
        return _DeviceAnalyticsCard(
          deviceId: deviceId,
          stats: stats,
        );
      },
    );
  }

  String _getEventTypeLabel(ConnectionEventType type) {
    switch (type) {
      case ConnectionEventType.connect:
        return 'Connect';
      case ConnectionEventType.disconnect:
        return 'Disconnect';
      case ConnectionEventType.authSuccess:
        return 'Auth OK';
      case ConnectionEventType.authFailure:
        return 'Auth Fail';
      case ConnectionEventType.sessionStart:
        return 'Session Start';
      case ConnectionEventType.sessionEnd:
        return 'Session End';
    }
  }

  Color _getEventTypeColor(
    ConnectionEventType type,
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case ConnectionEventType.connect:
      case ConnectionEventType.sessionStart:
        return cs.primary;
      case ConnectionEventType.disconnect:
      case ConnectionEventType.sessionEnd:
        return cs.onSurfaceVariant;
      case ConnectionEventType.authSuccess:
        return AppColors.success;
      case ConnectionEventType.authFailure:
        return cs.error;
    }
  }
}

/// A connection event card
class _ConnectionEventCard extends StatelessWidget {
  const _ConnectionEventCard({required this.event});

  final ConnectionEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _getEventIcon();
    final color = _getEventColor(cs);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SettingsIconContainer(
            icon: icon,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getEventTitle(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${event.deviceName}  ·  '
                  '${event.username}'
                  '${event.ipAddress != null ? '  ·  ${event.ipAddress}' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatTime(event.timestamp),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon() {
    switch (event.eventType) {
      case ConnectionEventType.connect:
        return Icons.login;
      case ConnectionEventType.disconnect:
        return Icons.logout;
      case ConnectionEventType.authSuccess:
        return Icons.verified_user;
      case ConnectionEventType.authFailure:
        return Icons.gpp_bad;
      case ConnectionEventType.sessionStart:
        return Icons.play_circle;
      case ConnectionEventType.sessionEnd:
        return Icons.stop_circle;
    }
  }

  Color _getEventColor(ColorScheme cs) {
    switch (event.eventType) {
      case ConnectionEventType.connect:
      case ConnectionEventType.sessionStart:
        return cs.primary;
      case ConnectionEventType.disconnect:
      case ConnectionEventType.sessionEnd:
        return cs.onSurfaceVariant;
      case ConnectionEventType.authSuccess:
        return AppColors.success;
      case ConnectionEventType.authFailure:
        return cs.error;
    }
  }

  String _getEventTitle() {
    switch (event.eventType) {
      case ConnectionEventType.connect:
        return 'Connected';
      case ConnectionEventType.disconnect:
        return 'Disconnected'
            '${event.reason != null ? ': ${event.reason}' : ''}';
      case ConnectionEventType.authSuccess:
        return 'Authentication successful';
      case ConnectionEventType.authFailure:
        return 'Authentication failed';
      case ConnectionEventType.sessionStart:
        return 'Session started';
      case ConnectionEventType.sessionEnd:
        final dur = event.duration;
        return 'Session ended'
            '${dur != null ? ' (${_formatDuration(dur)})' : ''}';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}

/// A filter chip for event types
class _EventTypeChip extends StatelessWidget {
  const _EventTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.sm,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : null,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor:
          color ?? Theme.of(context).colorScheme.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ),
      materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Device analytics card
class _DeviceAnalyticsCard extends StatelessWidget {
  const _DeviceAnalyticsCard({
    required this.deviceId,
    required this.stats,
  });

  final String deviceId;
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDuration = stats['totalDuration'] as Duration;
    final avgDuration = stats['avgDuration'] as Duration;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconContainer(
                icon: Icons.dns_outlined,
                color: cs.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  deviceId,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _AnalyticsItem(
                label: 'Connections',
                value:
                    stats['totalConnections'].toString(),
                icon: Icons.link,
                color: cs.primary,
              ),
              _AnalyticsItem(
                label: 'Sessions',
                value: stats['totalSessions'].toString(),
                icon: Icons.terminal,
                color: cs.tertiary,
              ),
              _AnalyticsItem(
                label: 'Auth Failures',
                value: stats['authFailures'].toString(),
                icon: Icons.gpp_bad,
                color: cs.error,
              ),
              _AnalyticsItem(
                label: 'Unique Users',
                value: stats['uniqueUsers'].toString(),
                icon: Icons.people,
                color: cs.secondary,
              ),
              _AnalyticsItem(
                label: 'Total Time',
                value: _formatDuration(totalDuration),
                icon: Icons.timer,
                color: AppColors.warning,
              ),
              _AnalyticsItem(
                label: 'Avg Session',
                value: _formatDuration(avgDuration),
                icon: Icons.av_timer,
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m';
    }
    return '${d.inSeconds}s';
  }
}

/// An analytics metric item
class _AnalyticsItem extends StatelessWidget {
  const _AnalyticsItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
