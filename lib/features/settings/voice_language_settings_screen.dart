import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// A voice language option displayed in the list.
class _VoiceLanguageOption {

  const _VoiceLanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
  });
  final String code;
  final String name;
  final String nativeName;
}

/// Hardcoded set of supported voice languages.
const _voiceLanguages = <_VoiceLanguageOption>[
  _VoiceLanguageOption(code: '', name: 'Auto-detect', nativeName: ''),
  _VoiceLanguageOption(
    code: 'en',
    name: 'English',
    nativeName: 'English',
  ),
  _VoiceLanguageOption(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Espanol',
  ),
  _VoiceLanguageOption(
    code: 'fr',
    name: 'French',
    nativeName: 'Francais',
  ),
  _VoiceLanguageOption(
    code: 'de',
    name: 'German',
    nativeName: 'Deutsch',
  ),
  _VoiceLanguageOption(
    code: 'it',
    name: 'Italian',
    nativeName: 'Italiano',
  ),
  _VoiceLanguageOption(
    code: 'pt',
    name: 'Portuguese',
    nativeName: 'Portugues',
  ),
  _VoiceLanguageOption(
    code: 'pl',
    name: 'Polish',
    nativeName: 'Polski',
  ),
  _VoiceLanguageOption(
    code: 'nl',
    name: 'Dutch',
    nativeName: 'Nederlands',
  ),
  _VoiceLanguageOption(
    code: 'ru',
    name: 'Russian',
    nativeName: 'Russkij',
  ),
  _VoiceLanguageOption(
    code: 'ja',
    name: 'Japanese',
    nativeName: 'Nihongo',
  ),
  _VoiceLanguageOption(
    code: 'zh',
    name: 'Chinese (Simplified)',
    nativeName: 'Zhongwen',
  ),
  _VoiceLanguageOption(
    code: 'ko',
    name: 'Korean',
    nativeName: 'Hangugeo',
  ),
  _VoiceLanguageOption(
    code: 'ar',
    name: 'Arabic',
    nativeName: 'Arabi',
  ),
  _VoiceLanguageOption(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'Hindi',
  ),
  _VoiceLanguageOption(
    code: 'sv',
    name: 'Swedish',
    nativeName: 'Svenska',
  ),
  _VoiceLanguageOption(
    code: 'da',
    name: 'Danish',
    nativeName: 'Dansk',
  ),
  _VoiceLanguageOption(
    code: 'fi',
    name: 'Finnish',
    nativeName: 'Suomi',
  ),
  _VoiceLanguageOption(
    code: 'tr',
    name: 'Turkish',
    nativeName: 'Turkce',
  ),
  _VoiceLanguageOption(
    code: 'uk',
    name: 'Ukrainian',
    nativeName: 'Ukrainska',
  ),
];

/// Voice language settings screen — shows available languages and saves
/// the selected one to settings.
class VoiceLanguageSettingsScreen extends ConsumerStatefulWidget {
  const VoiceLanguageSettingsScreen({super.key});

  @override
  ConsumerState<VoiceLanguageSettingsScreen> createState() =>
      _VoiceLanguageSettingsScreenState();
}

class _VoiceLanguageSettingsScreenState
    extends ConsumerState<VoiceLanguageSettingsScreen> {
  String _searchQuery = '';

  List<_VoiceLanguageOption> get _filtered {
    if (_searchQuery.isEmpty) {
      return _voiceLanguages;
    }
    final query = _searchQuery.toLowerCase();
    return _voiceLanguages.where((lang) {
      return lang.name.toLowerCase().contains(query) ||
          lang.nativeName.toLowerCase().contains(query) ||
          lang.code.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectLanguage(_VoiceLanguageOption lang) async {
    await ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting(
          'voiceAssistantLanguage',
          lang.code.isEmpty ? null : lang.code,
        );
    if (mounted) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final selectedCode = settings.voiceAssistantLanguage ?? '';
    final theme = Theme.of(context);
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceLanguageTitle),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchLanguages,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.smd),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Count footer
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.voiceLanguagesCount(filtered.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Language list
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final lang = filtered[index];
                final isSelected = selectedCode == lang.code;

                return ListTile(
                  leading: const Icon(
                    Icons.language,
                    color: AppColors.iosBlue,
                  ),
                  title: Text(lang.name),
                  subtitle: lang.nativeName.isNotEmpty
                      ? Text(lang.nativeName)
                      : null,
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  selected: isSelected,
                  onTap: () => _selectLanguage(lang),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
