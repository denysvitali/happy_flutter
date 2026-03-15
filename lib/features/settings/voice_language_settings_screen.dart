import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

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

const _voiceLanguages = <_VoiceLanguageOption>[
  _VoiceLanguageOption(
    code: '',
    name: 'Auto-detect',
    nativeName: '',
  ),
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

class VoiceLanguageSettingsScreen
    extends ConsumerStatefulWidget {
  const VoiceLanguageSettingsScreen({super.key});

  @override
  ConsumerState<VoiceLanguageSettingsScreen>
      createState() =>
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
          lang.nativeName
              .toLowerCase()
              .contains(query) ||
          lang.code.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectLanguage(
    _VoiceLanguageOption lang,
  ) async {
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
    final selectedCode =
        settings.voiceAssistantLanguage ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceLanguageTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchLanguages,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppRadius.smd,
                  ),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.voiceLanguagesCount(filtered.length),
                style:
                    theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children:
                        _buildLanguageList(filtered, selectedCode),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLanguageList(
    List<_VoiceLanguageOption> languages,
    String selectedCode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    for (var i = 0; i < languages.length; i++) {
      final lang = languages[i];
      final isSelected = selectedCode == lang.code;

      if (i > 0) {
        widgets.add(
          Divider(
            height: 1,
            thickness: AppBorder.hairline,
            indent: AppSpacing.lg,
            endIndent: 0,
            color: cs.outlineVariant,
          ),
        );
      }

      widgets.add(
        InkWell(
          onTap: () => _selectLanguage(lang),
          child: Container(
            color: isSelected
                ? cs.primary.withValues(
                    alpha: AppOpacity.faint,
                  )
                : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: AppColors.iosBlue,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (lang.nativeName.isNotEmpty) ...[
                        const SizedBox(
                          height: AppSpacing.xxs,
                        ),
                        Text(
                          lang.nativeName,
                          style: theme
                              .textTheme.bodySmall
                              ?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: cs.primary,
                    size: AppSpacing.xl,
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurface.withValues(
                      alpha: AppOpacity.medium,
                    ),
                    size: AppSpacing.xl,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}
