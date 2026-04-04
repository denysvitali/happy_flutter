import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/connection_event.dart';
import '../services/connection_history_store.dart';
import 'widgets/connection_event_card.dart';
import 'widgets/device_analytics_card.dart';

export '../models/connection_event.dart';
export '../services/connection_history_store.dart';
export 'widgets/connection_event_card.dart';
export 'widgets/device_analytics_card.dart';

/// Screen for viewing SFTP connection history
class SftpConnectionHistoryScreen extends StatefulWidget {
  const SftpConnectionHistoryScreen({
    super.key,
    this.deviceId,
  });

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
          const SnackBar(
            content: Text('No events to export'),
          ),
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
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          child: Column(
            children: [
              Row(
                children: [
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    EventTypeChip(
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
                        child: EventTypeChip(
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
                style:
                    Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'Max: 5,000',
                style:
                    Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
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
                    return ConnectionEventCard(
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
        return DeviceAnalyticsCard(
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
