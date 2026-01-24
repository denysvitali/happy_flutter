import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/languages.dart';

/// Language settings screen - Language picker with 15+ languages
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final preferredLanguage = settings.preferredLanguage;

    // Get detected device language
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final detectedLanguage = locale.languageCode;
    final detectedLanguageName = supportedLanguages.containsKey(detectedLanguage)
        ? getLanguageNativeName(detectedLanguage)
        : getLanguageNativeName('en');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Automatic detection option
          _buildLanguageOption(
            context: context,
            code: 'auto',
            title: 'Automatic',
            subtitle: 'Use device language ($detectedLanguageName)',
            isSelected: preferredLanguage == null,
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('preferredLanguage', null);
              context.pop();
            },
          ),
          const SizedBox(height: 8),
          // Divider
          const Divider(),
          const SizedBox(height: 8),
          // All supported languages
          ...supportedLanguages.entries.map((entry) {
            final code = entry.key;
            final info = entry.value;
            return Column(
              children: [
                _buildLanguageOption(
                  context: context,
                  code: code,
                  title: info.nativeName,
                  subtitle: info.englishName,
                  isSelected: preferredLanguage == code,
                  onTap: () {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateSetting('preferredLanguage', code);
                    context.pop();
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String code,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
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
