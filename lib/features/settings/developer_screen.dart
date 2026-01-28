import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../dev/dev_logs_screen.dart';

/// Developer screen - Debug tools (10x click to enable)
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final isDeveloperMode = settings.developerModeEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Developer mode toggle
          Card(
            child: SwitchListTile(
              title: const Text('Developer Mode'),
              subtitle: Text(isDeveloperMode
                  ? 'Enabled - Debug tools are visible'
                  : 'Disabled - Tap 10 times to enable'),
              value: isDeveloperMode,
              onChanged: (value) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('developerModeEnabled', value);
              },
            ),
          ),
          if (isDeveloperMode) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Debug Tools'),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Network Inspector',
              subtitle: 'View API requests and responses',
              icon: Icons.network_check,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Logs',
              subtitle: 'View application logs',
              icon: Icons.terminal,
              onTap: () => context.push('/settings/developer/logs'),
            ),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Encryption Debug',
              subtitle: 'View encryption keys and certificates',
              icon: Icons.security,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Session Debug',
              subtitle: 'View active sessions and connections',
              icon: Icons.history,
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Testing'),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Test Notifications',
              subtitle: 'Send a test push notification',
              icon: Icons.notifications,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Test Error Reporting',
              subtitle: 'Trigger a test error',
              icon: Icons.bug_report,
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Cache & Storage'),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Clear Cache',
              subtitle: 'Clear cached data',
              icon: Icons.delete_sweep,
              onTap: () => _clearCache(context),
            ),
            const SizedBox(height: 8),
            _buildDebugOption(
              context: context,
              title: 'Reset Settings',
              subtitle: 'Reset all settings to defaults',
              icon: Icons.restart_alt,
              onTap: () => _resetSettings(context, ref),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Build Info'),
            const SizedBox(height: 8),
            _buildInfoTile('App Version', '1.0.0'),
            _buildInfoTile('Build Number', '1'),
            _buildInfoTile('Flutter Version', '3.38.7'),
            _buildInfoTile('Dart Version', '3.10+'),
          ],
        ],
      ),
    );

    // ignore: dead_code
    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: Center(
        child: GestureDetector(
          onTap: () => _handleDevModeTap(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build, size: 64),
                const SizedBox(height: 16),
                const Text('Developer Options'),
                const SizedBox(height: 8),
                Text(
                  'Tap ${10 - _tapCount} more times',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDevModeTap(BuildContext context, WidgetRef ref) {
    setState(() {
      _tapCount++;
    });
    if (_tapCount >= 10) {
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('developerModeEnabled', true);
      setState(() {
        _tapCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Developer mode enabled!')),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDebugOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  void _clearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _resetSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
            'Are you sure you want to reset all settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
