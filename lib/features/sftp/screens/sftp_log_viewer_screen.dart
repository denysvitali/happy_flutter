import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../models/sftp_log.dart';

/// Log level filter
enum LogLevelFilter { all, info, warning, error }

/// Screen for viewing and managing SFTP server logs
class SftpLogViewerScreen extends StatefulWidget {
  const SftpLogViewerScreen({super.key, this.initialDeviceId});

  final String? initialDeviceId;

  @override
  State<SftpLogViewerScreen> createState() => _SftpLogViewerScreenState();
}

class _SftpLogViewerScreenState extends State<SftpLogViewerScreen>
    with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: 2, vsync: this);
    _selectedDeviceId = widget.initialDeviceId;
    _loadLogs();

    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadLogs(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadLogs() {
    if (!mounted) return;
    setState(() {
      if (_selectedDeviceId != null) {
        _allLogs = sftpLogStore.getLogs(_selectedDeviceId!);
      } else {
        // Aggregate logs from all devices
        final allLogs = <SftpLogEntry>[];
        for (final deviceId in sftpLogStore.deviceIdsWithLogs) {
          allLogs.addAll(sftpLogStore.getLogs(deviceId));
        }
        allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
      logs = logs.where((l) => l.level == levelName).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      logs = logs.where((l) {
        return l.message.toLowerCase().contains(query) ||
            (l.username?.toLowerCase().contains(query) ?? false) ||
            (l.operation?.toLowerCase().contains(query) ?? false) ||
            (l.details?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    _filteredLogs = logs;
  }

  Future<void> _exportLogs() async {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs to export')),
        );
      }
      return;
    }

    final jsonStr = jsonEncode(logs.map((l) => l.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${logs.length} log entries copied to clipboard'),
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

    if (confirmed == true) {
      if (_selectedDeviceId != null) {
        await sftpLogStore.clearDeviceLogs(_selectedDeviceId!);
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
        const SnackBar(content: Text('Old logs rotated')),
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
            onPressed: _filteredLogs.isNotEmpty ? _exportLogs : null,
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
          preferredSize: const Size.fromHeight(48),
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
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              // Device selector row
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.devices, size: 18),
                  const SizedBox(width: 8),
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
                                overflow: TextOverflow.ellipsis,
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
                    final isSelected = _levelFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        label: Text(
                          filter.name[0].toUpperCase() +
                              filter.name.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
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
                        selectedColor: filter == LogLevelFilter.error
                            ? Colors.red
                            : filter == LogLevelFilter.warning
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 4),
              // Search bar
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Text(
                '${_filteredLogs.length} entries',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (_allLogs.isNotEmpty)
                Text(
                  'Total: ${sftpLogStore.totalLogCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        // Log list
        Expanded(
          child: _filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _allLogs.isEmpty
                            ? 'No logs yet'
                            : 'No logs match filters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _allLogs.isEmpty
                            ? 'Logs will appear here when SFTP clients connect'
                            : 'Try adjusting your filters',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadLogs(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      return _LogEntryTile(
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
    // Aggregate statistics
    var totalLogs = 0;
    var errorCount = 0;
    var warningCount = 0;
    var infoCount = 0;
    final opCounts = <String, int>{};
    final userCounts = <String, int>{};

    for (final deviceId in sftpLogStore.deviceIdsWithLogs) {
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
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            _StatCard(
              label: 'Total',
              value: totalLogs.toString(),
              icon: Icons.article,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Errors',
              value: errorCount.toString(),
              icon: Icons.error_outline,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Warnings',
              value: warningCount.toString(),
              icon: Icons.warning_amber,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatCard(
              label: 'Info',
              value: infoCount.toString(),
              icon: Icons.info_outline,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Devices',
              value: deviceIds.length.toString(),
              icon: Icons.devices,
              color: Colors.purple,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Retention',
              value: '7d',
              icon: Icons.schedule,
              color: Colors.teal,
            ),
          ],
        ),

        // Operations breakdown
        if (opCounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Operations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._buildSortedEntries(
            opCounts,
            (e) => ListTile(
              dense: true,
              title: Text(e.key),
              trailing: Text(
                e.value.toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              leading: _getOperationIcon(e.key, context),
            ),
          ),
        ],

        // Users breakdown
        if (userCounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Users',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._buildSortedEntries(
            userCounts,
            (e) => ListTile(
              dense: true,
              leading: const Icon(Icons.person, size: 20),
              title: Text(e.key),
              trailing: Text(
                e.value.toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        ],

        // Storage info
        const SizedBox(height: 24),
        Text(
          'Storage',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ListTile(
          dense: true,
          leading: const Icon(Icons.storage, size: 20),
          title: const Text('Max logs per device'),
          trailing: const Text('1,000'),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.timer, size: 20),
          title: const Text('Log retention'),
          trailing: const Text('7 days'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _rotateLogs,
          icon: const Icon(Icons.cleaning_services, size: 18),
          label: const Text('Rotate old logs now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _clearLogs,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Clear all logs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }

  Icon _getOperationIcon(String operation, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (operation.toLowerCase()) {
      case 'connect':
        return Icon(Icons.login, size: 20, color: cs.primary);
      case 'disconnect':
        return Icon(Icons.logout, size: 20, color: cs.onSurfaceVariant);
      case 'read':
      case 'get':
        return Icon(
          Icons.file_download,
          size: 20,
          color: AppColors.success,
        );
      case 'write':
      case 'put':
        return Icon(
          Icons.file_upload,
          size: 20,
          color: AppColors.warning,
        );
      case 'list':
        return Icon(Icons.folder_open, size: 20, color: cs.tertiary);
      case 'delete':
      case 'remove':
        return Icon(Icons.delete, size: 20, color: cs.error);
      case 'rename':
      case 'move':
        return const Icon(Icons.drive_file_rename_outline, size: 20);
      case 'mkdir':
        return const Icon(Icons.create_new_folder, size: 20);
      case 'chmod':
        return const Icon(Icons.security, size: 20);
      default:
        return Icon(Icons.circle, size: 20, color: cs.onSurfaceVariant);
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

/// A single log entry tile
class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.log, this.onDeviceTap});

  final SftpLogEntry log;
  final void Function(String deviceId)? onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(context);
    final levelIcon = _getLevelIcon();

    return ExpansionTile(
      leading: Icon(levelIcon, color: levelColor, size: 20),
      title: Text(
        log.message,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            _formatTime(log.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (log.operation != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.operation!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
          if (log.username != null) ...[
            const SizedBox(width: 8),
            Text(
              log.username!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Device', value: log.deviceName),
              GestureDetector(
                onTap: () => onDeviceTap?.call(log.deviceId),
                child: _DetailRow(
                  label: 'Device ID',
                  value: log.deviceId,
                  valueColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              _DetailRow(label: 'Level', value: log.level),
              if (log.username != null)
                _DetailRow(label: 'Username', value: log.username!),
              if (log.ipAddress != null)
                _DetailRow(label: 'IP Address', value: log.ipAddress!),
              if (log.operation != null)
                _DetailRow(label: 'Operation', value: log.operation!),
              _DetailRow(
                label: 'Time',
                value: log.timestamp.toIso8601String(),
              ),
              if (log.details != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    log.details!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _getLevelColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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

    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (valueColor != null
                      ? Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: valueColor,
                            decoration: TextDecoration.underline,
                          )
                      : Theme.of(context).textTheme.bodySmall)
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
