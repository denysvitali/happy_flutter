import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/voice_languages.dart';

/// Voice settings screen - TTS and voice language selection
class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  ConsumerState<VoiceSettingsScreen> createState() =>
      _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends ConsumerState<VoiceSettingsScreen> {
  List<Map<String, String>> _engines = [];
  bool _enginesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadEngines();
  }

  Future<void> _loadEngines() async {
    final engines = await TtsService().getEngines();
    if (mounted) {
      setState(() {
        _engines = engines;
        _enginesLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final selectedLanguageCode = settings.voiceAssistantLanguage ?? '';
    final selectedLanguage = findVoiceLanguageByCode(selectedLanguageCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          SettingsSection(
            title: l10n.voiceTtsTitle,
            children: [
              SettingsToggleRow(
                icon: Icons.volume_up_outlined,
                title: l10n.voiceTtsTitle,
                subtitle: l10n.voiceTtsSubtitle,
                value: settings.ttsEnabled,
                onChanged: (value) => ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('ttsEnabled', value),
              ),
              SettingsNavRow(
                icon: Icons.play_arrow,
                title: l10n.voiceTestTts,
                subtitle: l10n.voiceTestTtsSubtitle,
                onTap: () async {
                  final tts = TtsService();
                  await tts.init(
                    language:
                        settings.voiceAssistantLanguage,
                    engine: settings.ttsEngine,
                  );
                  await tts.speak(
                    'Hello! Text to speech is working.',
                  );
                },
              ),
            ],
          ),
          if (_enginesLoaded &&
              _engines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.voiceSelectEngineHint,
              uppercase: false,
              children: [
                SettingsRow(
                  icon: Icons.settings_voice,
                  iconColor: settings.ttsEngine == null
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                      : null,
                  title: l10n.voiceDefaultEngine,
                  subtitle:
                      l10n.voiceDefaultEngineSubtitle,
                  trailing: settings.ttsEngine == null
                      ? Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                        )
                      : null,
                  onTap: () {
                    ref
                        .read(
                          settingsNotifierProvider
                              .notifier,
                        )
                        .updateSetting(
                          'ttsEngine',
                          null,
                        );
                  },
                ),
                ..._engines.map((engine) {
                  final engineName =
                      engine['name'] ?? 'Unknown';
                  final engineId =
                      engine['identifier'] ?? '';
                  final isSelected =
                      settings.ttsEngine == engineId;
                  return SettingsRow(
                    icon: Icons.settings_voice,
                    iconColor: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                        : null,
                    title: engineName,
                    subtitle: engineId,
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          )
                        : null,
                    onTap: () {
                      ref
                          .read(
                            settingsNotifierProvider
                                .notifier,
                          )
                          .updateSetting(
                            'ttsEngine',
                            engineId,
                          );
                    },
                  );
                }),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.voiceSelectLanguageHint,
            uppercase: false,
            children: [
              SettingsRow(
                icon: Icons.record_voice_over,
                iconColor: selectedLanguageCode.isEmpty
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                    : null,
                title: voiceLanguages[0].name,
                subtitle: voiceLanguages[0].region ??
                    voiceLanguages[0].nativeName,
                trailing: selectedLanguageCode.isEmpty
                    ? Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(
                        settingsNotifierProvider.notifier,
                      )
                      .updateSetting(
                        'voiceAssistantLanguage',
                        null,
                      );
                },
              ),
              SettingsNavRow(
                icon: Icons.language,
                title: l10n.voiceLanguageTitle,
                subtitle: selectedLanguage?.displayName ??
                    l10n.voiceAutoDetect,
                onTap: () =>
                    context.pushNamed('voice-language'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

}

/// Voice language selection screen with search functionality
class VoiceLanguageSelectionScreen extends ConsumerStatefulWidget {
  const VoiceLanguageSelectionScreen({super.key});

  @override
  ConsumerState<VoiceLanguageSelectionScreen> createState() =>
      _VoiceLanguageSelectionScreenState();
}

class _VoiceLanguageSelectionScreenState
    extends ConsumerState<VoiceLanguageSelectionScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = searchVoiceLanguages(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).voiceSelectLanguageTitle),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: Theme.of(context).colorScheme.surface,
            child: TextField(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchLanguages,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.smd),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Language count footer
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              AppLocalizations.of(
                context,
              ).voiceLanguagesCount(filteredLanguages.length),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          // Language list
          Expanded(
            child: ListView.builder(
              itemCount: filteredLanguages.length,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              itemBuilder: (context, index) {
                final language =
                    filteredLanguages[index];
                final isSelected =
                    _isLanguageSelected(language);

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.xs,
                  ),
                  child: Card(
                    key: ValueKey(language.code),
                    child: SettingsRow(
                      icon: Icons.language,
                      iconColor: AppColors.iosBlue,
                      title: language.displayName,
                      subtitle: language.subtitle,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            )
                          : null,
                      onTap: () =>
                          _selectLanguage(language),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isLanguageSelected(VoiceLanguage language) {
    final currentState = ref.read(settingsNotifierProvider);
    final currentCode = currentState.voiceAssistantLanguage ?? '';
    return currentCode == language.code;
  }

  void _selectLanguage(VoiceLanguage language) {
    ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting(
          'voiceAssistantLanguage',
          language.code.isEmpty ? null : language.code,
        );
    Navigator.pop(context);
  }
}
