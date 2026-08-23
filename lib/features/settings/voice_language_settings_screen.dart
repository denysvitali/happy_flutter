import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/voice_languages.dart';

/// Picker for the voice assistant language. Sources its entries from
/// the shared catalog in `core/utils/voice_languages.dart` (the same
/// list used by chat/TTS) and persists the selection under the
/// `voiceAssistantLanguage` settings key.
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
  bool _isPopping = false;

  List<VoiceLanguage> get _filtered =>
      searchVoiceLanguages(_searchQuery);

  /// Secondary line for a row: the native script when it differs from
  /// the English name, otherwise the region (so the English/Spanish/
  /// … variants stay distinguishable). Empty for auto-detect.
  String _subtitleFor(VoiceLanguage lang) {
    if (lang.nativeName.isNotEmpty &&
        lang.nativeName != lang.name) {
      return lang.nativeName;
    }
    return lang.region ?? '';
  }

  Future<void> _selectLanguage(VoiceLanguage lang) async {
    if (_isPopping) return;
    _isPopping = true;
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting(
            'voiceAssistantLanguage',
            lang.code.isEmpty ? null : lang.code,
          );
      if (mounted) {
        await Navigator.of(context).maybePop();
        if (mounted) _isPopping = false;
      }
    } catch (_) {
      if (mounted) _isPopping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCode =
        ref.watch(settingsNotifierProvider.select(
              (s) => s.voiceAssistantLanguage,
            )) ??
            '';
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
    List<VoiceLanguage> languages,
    String selectedCode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    for (var i = 0; i < languages.length; i++) {
      final lang = languages[i];
      final isSelected = selectedCode == lang.code;
      final subtitle = _subtitleFor(lang);

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
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(
                          height: AppSpacing.xxs,
                        ),
                        Text(
                          subtitle,
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
