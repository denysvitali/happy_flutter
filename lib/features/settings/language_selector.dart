import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/supported_locales.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';

/// Language selector widget for settings.
///
/// Allows users to select their preferred language from the supported locales.
class LanguageSelector extends ConsumerWidget {
  /// Whether to show a full settings screen or just the selector.
  final bool isFullScreen;

  const LanguageSelector({
    super.key,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final currentLocale = _parseLocale(settings.preferredLanguage ?? '');
    final l10n = context.l10n;

    if (isFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.settingsLanguage),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Automatic detection option
            ListTile(
              title: Text(l10n.settingsLanguageAutomatic),
              subtitle: Text(l10n.settingsLanguageAutomaticSubtitle),
              leading: const Icon(Icons.auto_awesome),
                selected: (settings.preferredLanguage?.isEmpty ?? true),
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              onTap: () {
                ref.read(settingsNotifierProvider.notifier).updateSetting(
                      'locale',
                      '',
                    );
                context.pop();
              },
            ),
            const Divider(),
            // Supported languages
            ...supportedLocales.map(
              (locale) => ListTile(
                title: Text(getLocaleDisplayName(locale)),
                leading: Radio<Locale>(
                  value: locale,
                  groupValue: currentLocale,
                  onChanged: (Locale? value) {
                    if (value != null) {
                      final localeString = value.scriptCode != null
                          ? '${value.languageCode}_${value.scriptCode}'
                          : value.languageCode;
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSetting('locale', localeString);
                      context.pop();
                    }
                  },
                ),
                selected: _isSameLocale(currentLocale, locale),
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                onTap: () {
                  final localeString = locale.scriptCode != null
                      ? '${locale.languageCode}_${locale.scriptCode}'
                      : locale.languageCode;
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .updateSetting('locale', localeString);
                  context.pop();
                },
              ),
            ),
          ],
        ),
      );
    }

    // Compact selector for embedding in other screens
    return ListTile(
      title: Text(l10n.settingsLanguage),
      subtitle: Text(
        (settings.preferredLanguage?.isEmpty ?? true)
            ? l10n.settingsLanguageAutomatic
            : getLocaleDisplayName(currentLocale),
      ),
      leading: const Icon(Icons.language),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context, ref, currentLocale),
    );
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale currentLocale,
  ) async {
    final l10n = context.l10n;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Automatic detection
            RadioListTile<String>(
              title: Text(l10n.settingsLanguageAutomatic),
              subtitle: Text(l10n.settingsLanguageAutomaticSubtitle),
              value: '',
              groupValue: ref.read(settingsNotifierProvider).locale,
              onChanged: (value) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('locale', value ?? '');
                context.pop();
              },
            ),
            const Divider(),
            // Supported languages
            ...supportedLocales.map(
              (locale) {
                final localeString = locale.scriptCode != null
                    ? '${locale.languageCode}_${locale.scriptCode}'
                    : locale.languageCode;
                return RadioListTile<String>(
                  title: Text(getLocaleDisplayName(locale)),
                  value: localeString,
                  groupValue: ref.read(settingsNotifierProvider).preferredLanguage,
                  onChanged: (value) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateSetting('locale', value ?? '');
                    context.pop();
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Locale _parseLocale(String localeString) {
    if (localeString.isEmpty) {
      return const Locale('en');
    }
    return parseLocale(localeString);
  }

  bool _isSameLocale(Locale a, Locale b) {
    return a.languageCode == b.languageCode &&
        (a.scriptCode ?? '') == (b.scriptCode ?? '');
  }
}
