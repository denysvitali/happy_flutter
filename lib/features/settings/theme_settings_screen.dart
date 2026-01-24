import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';

/// Theme settings screen - Adaptive/Light/Dark theme selection
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildThemeOption(
            context: context,
            title: 'System',
            subtitle: 'Use device theme settings',
            icon: Icons.brightness_auto,
            isSelected: settings.themeMode == 'system',
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('themeMode', 'system');
            },
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context: context,
            title: 'Light',
            subtitle: 'Always use light theme',
            icon: Icons.light_mode,
            isSelected: settings.themeMode == 'light',
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('themeMode', 'light');
            },
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context: context,
            title: 'Dark',
            subtitle: 'Always use dark theme',
            icon: Icons.dark_mode,
            isSelected: settings.themeMode == 'dark',
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('themeMode', 'dark');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
