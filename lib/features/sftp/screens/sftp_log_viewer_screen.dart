import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_card.dart';
import '../../../core/components/app_empty_state.dart';
import '../../../core/components/app_section_header.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/sftp_log.dart';

/// Log level filter
enum LogLevelFilter { all, info, warning, error }

/// Screen for viewing and managing SFTP server logs
class SftpLogViewerScreen extends StatefulWidget {
  const SftpLogViewerScreen({
    super.key,
    this.initialDeviceId,
  });

  final String? initialDeviceId;

  @override
  State<SftpLogViewerScreen> createState() =>
      _SftpLogViewerScreenState();
}

class _SftpLogViewerScreenState
    extends State<SftpLogViewerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? _selectedDeviceId;
  LogLevelFilter _levelFilter = LogLevelFilter.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  late TabController _tabController;

  List<SftpLogEntry> _allLogs = [];
  List<SftpLogEntry> _filteredLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _selectedDeviceId = widget.initialDeviceId;
    _loadLogs();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadLogs();
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadLogs(),
    );
  }

  void _loadLogs() {
    if (!mounted) return;
    setState(() {
      if (_selectedDeviceId != null) {
        _allLogs =
            sftpLogStore.getLogs(_selectedDeviceId!);
      } else {
        // Aggregate logs from all devices
        final allLogs = <SftpLogEntry>[];
        for (final deviceId
            in sftpLogStore.deviceIdsWithLogs) {
          allLogs.addAll(sftpLogStore.getLogs(deviceId));
        }
        allLogs.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        );
        _allLogs = allLogs;
      }
      _applyFilters();
    });
  }

  void _applyFilters() {
    var logs = List<SftpLogEntry>.from(_allLogs);

    // Level filter
    if (_levelFilter != LogLevelFilter.all) {
      final levelName = _levelFilter.name;
      logs =
          logs.where((l) => l.level == levelName).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      logs = logs.where((l) {
        return l.message.toLowerCase().contains(query) ||
            (l.username?.toLowerCase().contains(query) ??
                false) ||
            (l.operation?.toLowerCase().contains(query) ??
                false) ||
            (l.details?.toLowerCase().contains(query) ??
                false);
      }).toList();
    }

    _filteredLogs = logs;
  }

  Future<void> _exportLogs() async {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No logs to export'),
          ),
        );
      }
      return;
    }

    final jsonStr =
        jsonEncode(logs.map((l) => l.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${logs.length} log entries copied '
            'to clipboard',
          ),
        ),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Logs'),
        content: Text(
          _selectedDeviceId != null
              ? 'Clear all logs for this device?'
              : 'Clear all SFTP logs?',
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
      if (_selectedDeviceId != null) {
        await sftpLogStore
            .clearDeviceLogs(_selectedDeviceId!);
      } else {
        await sftpLogStore.clearAll();
      }
      _loadLogs();
    }
  }

  Future<void> _rotateLogs() async {
    await sftpLogStore.rotateLogs();
    _loadLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Old logs rotated'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceIds = sftpLogStore.deviceIdsWithLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SFTP Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _filteredLogs.isNotEmpty
                ? _exportLogs
                : null,
            tooltip: 'Export logs',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _clearLogs();
                case 'rotate':
                  _rotateLogs();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rotate',
                child: Text('Rotate old logs'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear logs'),
              ),
            ],
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
                Tab(text: 'Logs'),
                Tab(text: 'Stats'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(deviceIds),
          _buildStatsTab(deviceIds),
        ],
      ),
    );
  }

  Widget _buildLogsTab(List<String> deviceIds) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          color: cs.surfaceContainerHighest,
          child: Column(
            children: [
              // Device selector row
              Row(
                children: [
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.devices,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedDeviceId,
                        isDense: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Devices'),
                          ),
                          ...deviceIds.map(
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
                            _loadLogs();
                          });
                        },
                      ),
                    ),
                  ),
                  // Level filter chips
                  ...LogLevelFilter.values.map((filter) {
                    final isSelected =
                        _levelFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.xs,
                      ),
                      child: ChoiceChip(
                        label: Text(
                          filter.name[0].toUpperCase() +
                              filter.name.substring(1),
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: isSelected
                                ? cs.onPrimary
                                : null,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _levelFilter = filter;
                            _applyFilters();
                          });
                        },
                        selectedColor: filter ==
                                LogLevelFilter.error
                            ? cs.error
                            : filter ==
                                    LogLevelFilter.warning
                                ? AppColors.warning
                                : cs.primary,
                        showCheckmark: false,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize
                                .shrinkWrap,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Search bar
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
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
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Log count bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Text(
                '${_filteredLogs.length} entries',
                style:
                    Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (_allLogs.isNotEmpty)
                Text(
                  'Total: ${sftpLogStore.totalLogCount}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
            ],
          ),
        ),
        // Log list
        Expanded(
          child: _filteredLogs.isEmpty
              ? AppEmptyState(
                  icon: Icons.article_outlined,
                  title: _allLogs.isEmpty
                      ? 'No logs yet'
                      : 'No logs match filters',
                  subtitle: _allLogs.isEmpty
                      ? 'Logs will appear here when '
                          'SFTP clients connect'
                      : 'Try adjusting your filters',
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadLogs(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: _filteredLogs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(
                      height: AppSpacing.xs,
                    ),
                    itemBuilder: (context, index) {
                      return _LogEntryCard(
                        log: _filteredLogs[index],
                        onDeviceTap: (deviceId) {
                          setState(() {
                            _selectedDeviceId = deviceId;
                            _loadLogs();
                          });
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(List<String> deviceIds) {
    final cs = Theme.of(context).colorScheme;

    // Aggregate statistics
    var totalLogs = 0;
    var errorCount = 0;
    var warningCount = 0;
    var infoCount = 0;
    final opCounts = <String, int>{};
    final userCounts = <String, int>{};

    for (final deviceId
        in sftpLogStore.deviceIdsWithLogs) {
      final logs = sftpLogStore.getLogs(deviceId);
      totalLogs += logs.length;
      for (final log in logs) {
        switch (log.level) {
          case 'error':
            errorCount++;
          case 'warning':
            warningCount++;
          default:
            infoCount++;
        }
        if (log.operation != null) {
          opCounts[log.operation!] =
              (opCounts[log.operation!] ?? 0) + 1;
        }
        if (log.username != null) {
          userCounts[log.username!] =
              (userCounts[log.username!] ?? 0) + 1;
        }
      }
    }

    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        // Summary cards
        Row(
          children: [
            _StatCard(
              label: 'Total',
              value: totalLogs.toString(),
              icon: Icons.article,
              color: cs.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
              label: 'Errors',
              value: errorCount.toString(),
              icon: Icons.error_outline,
              color: cs.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
              label: 'Warnings',
              value: warningCount.toString(),
              icon: Icons.warning_amber,
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _StatCard(
              label: 'Info',
              value: infoCount.toString(),
              icon: Icons.info_outline,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
              label: 'Devices',
              value: deviceIds.length.toString(),
              icon: Icons.devices,
              color: cs.tertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
              label: 'Retention',
              value: '7d',
              icon: Icons.schedule,
              color: cs.secondary,
            ),
          ],
        ),

        // Operations breakdown
        if (opCounts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(title: 'Operations'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _buildSortedEntries(
                opCounts,
                (e) => _StatsRow(
                  leading: _getOperationIcon(
                    e.key,
                    context,
                  ),
                  title: e.key,
                  trailing: e.value.toString(),
                ),
              ),
            ),
          ),
        ],

        // Users breakdown
        if (userCounts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(title: 'Users'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _buildSortedEntries(
                userCounts,
                (e) => _StatsRow(
                  leading: SettingsIconContainer(
                    icon: Icons.person,
                    color: cs.primary,
                  ),
                  title: e.key,
                  trailing: e.value.toString(),
                ),
              ),
            ),
          ),
        ],

        // Storage info
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: 'Storage'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _StatsRow(
                leading: SettingsIconContainer(
                  icon: Icons.storage,
                  color: cs.primary,
                ),
                title: 'Max logs per device',
                trailing: '1,000',
              ),
              Divider(
                height: 1,
                thickness: AppBorder.hairline,
                color: cs.outlineVariant,
              ),
              _StatsRow(
                leading: SettingsIconContainer(
                  icon: Icons.timer,
                  color: cs.secondary,
                ),
                title: 'Log retention',
                trailing: '7 days',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: _rotateLogs,
          icon: const Icon(
            Icons.cleaning_services,
            size: 18,
          ),
          label: const Text('Rotate old logs now'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _clearLogs,
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
          ),
          label: const Text('Clear all logs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
          ),
        ),
      ],
    );
  }

  Widget _getOperationIcon(
    String operation,
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    switch (operation.toLowerCase()) {
      case 'connect':
        return SettingsIconContainer(
          icon: Icons.login,
          color: cs.primary,
        );
      case 'disconnect':
        return SettingsIconContainer(
          icon: Icons.logout,
          color: cs.onSurfaceVariant,
        );
      case 'read':
      case 'get':
        return SettingsIconContainer(
          icon: Icons.file_download,
          color: AppColors.success,
        );
      case 'write':
      case 'put':
        return SettingsIconContainer(
          icon: Icons.file_upload,
          color: AppColors.warning,
        );
      case 'list':
        return SettingsIconContainer(
          icon: Icons.folder_open,
          color: cs.tertiary,
        );
      case 'delete':
      case 'remove':
        return SettingsIconContainer(
          icon: Icons.delete,
          color: cs.error,
        );
      case 'rename':
      case 'move':
        return SettingsIconContainer(
          icon: Icons.drive_file_rename_outline,
          color: cs.secondary,
        );
      case 'mkdir':
        return SettingsIconContainer(
          icon: Icons.create_new_folder,
          color: cs.tertiary,
        );
      case 'chmod':
        return SettingsIconContainer(
          icon: Icons.security,
          color: AppColors.warning,
        );
      default:
        return SettingsIconContainer(
          icon: Icons.circle,
          color: cs.onSurfaceVariant,
        );
    }
  }

  List<Widget> _buildSortedEntries(
    Map<String, int> counts,
    Widget Function(MapEntry<String, int>) builder,
  ) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).map(builder).toList();
  }
}

/// A single log entry card
class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({
    required this.log,
    this.onDeviceTap,
  });

  final SftpLogEntry log;
  final void Function(String deviceId)? onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final levelColor = _getLevelColor(cs);
    final levelIcon = _getLevelIcon();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
          childrenPadding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
          ),
          leading: SettingsIconContainer(
            icon: levelIcon,
            color: levelColor,
          ),
          title: Text(
            log.message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xxs,
            ),
            child: Row(
              children: [
                Text(
                  _formatTime(log.timestamp),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                if (log.operation != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.xs,
                      ),
                    ),
                    child: Text(
                      log.operation!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall,
                    ),
                  ),
                ],
                if (log.username != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    log.username!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: 'Device',
                  value: log.deviceName,
                ),
                GestureDetector(
                  onTap: () =>
                      onDeviceTap?.call(log.deviceId),
                  child: _DetailRow(
                    label: 'Device ID',
                    value: log.deviceId,
                    valueColor: cs.primary,
                  ),
                ),
                _DetailRow(
                  label: 'Level',
                  value: log.level,
                ),
                if (log.username != null)
                  _DetailRow(
                    label: 'Username',
                    value: log.username!,
                  ),
                if (log.ipAddress != null)
                  _DetailRow(
                    label: 'IP Address',
                    value: log.ipAddress!,
                  ),
                if (log.operation != null)
                  _DetailRow(
                    label: 'Operation',
                    value: log.operation!,
                  ),
                _DetailRow(
                  label: 'Time',
                  value:
                      log.timestamp.toIso8601String(),
                ),
                if (log.details != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Details',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium,
                  ),
                  const SizedBox(
                    height: AppSpacing.xs,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color:
                          cs.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.sm,
                      ),
                    ),
                    child: SelectableText(
                      log.details!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.sm,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(ColorScheme cs) {
    switch (log.level) {
      case 'error':
        return cs.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData _getLevelIcon() {
    switch (log.level) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

/// A detail row in the expanded log entry
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (valueColor != null
                      ? Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: valueColor,
                            decoration:
                                TextDecoration.underline,
                          )
                      : Theme.of(context)
                          .textTheme
                          .bodySmall)
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stat card for the stats tab
class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style:
                  Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A row for the stats breakdown sections
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style:
                  Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            trailing,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
