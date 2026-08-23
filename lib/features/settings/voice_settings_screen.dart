import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/offline_dictation_service.dart';
import '../../core/services/offline_tts_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/voice_languages.dart';
import 'widgets/voice_status_subtitles.dart';

class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  ConsumerState<VoiceSettingsScreen> createState() =>
      _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState
    extends ConsumerState<VoiceSettingsScreen> {
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
    final ttsEnabled = ref.watch(
      settingsNotifierProvider.select((s) => s.ttsEnabled),
    );
    final ttsUseOffline = ref.watch(
      settingsNotifierProvider.select((s) => s.ttsUseOffline),
    );
    final ttsEngine = ref.watch(
      settingsNotifierProvider.select((s) => s.ttsEngine),
    );
    final voiceAssistantLanguage = ref.watch(
      settingsNotifierProvider.select((s) => s.voiceAssistantLanguage),
    );
    final cs = Theme.of(context).colorScheme;
    final selectedLanguageCode = voiceAssistantLanguage ?? '';
    final selectedLanguage =
        findVoiceLanguageByCode(selectedLanguageCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceTitle)),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          SettingsSection(
            title: l10n.voiceTtsTitle,
            children: [
              SettingsToggleRow(
                icon: Icons.volume_up_outlined,
                title: l10n.voiceTtsTitle,
                subtitle: l10n.voiceTtsSubtitle,
                value: ttsEnabled,
                onChanged: (value) => ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('ttsEnabled', value),
              ),
              SettingsToggleRow(
                icon: Icons.cloud_off_outlined,
                title: l10n.voiceUseOfflineTitle,
                subtitle: l10n.voiceUseOfflineSubtitle,
                value: ttsUseOffline,
                onChanged: (value) => ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('ttsUseOffline', value),
              ),
              if (ttsUseOffline && TtsService().isOfflineSupported)
                const _OfflineVoicesNavRow(),
              const _OfflineSttModelsNavRow(),
              SettingsNavRow(
                icon: Icons.play_arrow,
                title: l10n.voiceTestTts,
                subtitle: l10n.voiceTestTtsSubtitle,
                onTap: () async {
                  final tts = TtsService();
                  await tts.init(
                    language: voiceAssistantLanguage,
                    engine: ttsEngine,
                  );
                  await tts.speak(
                    l10n.voiceTestTtsPhrase,
                    useOffline: ttsUseOffline,
                    offlineVoiceId:
                        ref.read(settingsNotifierProvider).ttsVoiceId,
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
                  iconColor: ttsEngine == null
                      ? cs.primary
                      : null,
                  title: l10n.voiceDefaultEngine,
                  subtitle:
                      l10n.voiceDefaultEngineSubtitle,
                  trailing: ttsEngine == null
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: AppSpacing.xl,
                          color: cs.primary,
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
                      engine['name'] ?? l10n.statusUnknown;
                  final engineId =
                      engine['identifier'] ?? '';
                  final isSelected =
                      ttsEngine == engineId;
                  return SettingsRow(
                    icon: Icons.settings_voice,
                    iconColor:
                        isSelected ? cs.primary : null,
                    title: engineName,
                    subtitle: engineId,
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            size: AppSpacing.xl,
                            color: cs.primary,
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
                    ? cs.primary
                    : null,
                title: voiceLanguages[0].name,
                subtitle: voiceLanguages[0].region ??
                    voiceLanguages[0].nativeName,
                trailing: selectedLanguageCode.isEmpty
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: AppSpacing.xl,
                        color: cs.primary,
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

/// Row that opens the offline-voice manager. Shows the active voice
/// and a quick status (downloaded / not downloaded / downloading).
class _OfflineVoicesNavRow extends ConsumerStatefulWidget {
  const _OfflineVoicesNavRow();

  @override
  ConsumerState<_OfflineVoicesNavRow> createState() =>
      _OfflineVoicesNavRowState();
}

class _OfflineVoicesNavRowState
    extends ConsumerState<_OfflineVoicesNavRow> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      TtsService().refreshOfflineVoiceStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final voices = TtsService().offlineVoices;
    if (voices.isEmpty) return const SizedBox.shrink();
    final selectedId = ref.watch(
      settingsNotifierProvider.select((s) => s.ttsVoiceId),
    );
    final active = voices.firstWhere(
      (v) => v.id == selectedId,
      orElse: () => voices.first,
    );

    return ValueListenableBuilder<Map<String, OfflineTtsStatus>>(
      valueListenable: TtsService().offlineVoiceStatuses,
      builder: (context, statuses, _) {
        final l10n = AppLocalizations.of(context);
        final statusStrings = DownloadStatusStrings(
          ready: l10n.voiceDownloadStatusReady,
          downloading: l10n.voiceDownloadStatusDownloading,
          failed: l10n.voiceDownloadStatusFailed,
          notDownloaded: l10n.voiceDownloadStatusNotDownloaded,
          failedRetrySuffix: l10n.voiceDownloadFailedRetrySuffix,
          notDownloadedSuffix: l10n.voiceDownloadNotDownloadedSuffix,
        );
        final status = statuses[active.id] ?? OfflineTtsStatus.notDownloaded;
        final readyCount = statuses.values
            .where((s) => s == OfflineTtsStatus.ready)
            .length;
        final subtitle = StringBuffer(active.displayName)
          ..write(' · ')
          ..write(downloadStatusLabel(
            ready: status == OfflineTtsStatus.ready,
            downloading: status == OfflineTtsStatus.downloading,
            failed: status == OfflineTtsStatus.failed,
            strings: statusStrings,
          ));
        if (readyCount > 0) {
          subtitle.write(' · $readyCount ${l10n.voiceInstalledLabel}');
        }
        return SettingsNavRow(
          icon: Icons.library_music_outlined,
          title: l10n.voiceOfflineVoicesTitle,
          subtitle: subtitle.toString(),
          onTap: () => context.pushNamed('voice-offline'),
        );
      },
    );
  }
}

/// Row that opens the offline STT model manager. Shows the active
/// dictation model and a quick status (downloaded / not / downloading).
class _OfflineSttModelsNavRow extends ConsumerStatefulWidget {
  const _OfflineSttModelsNavRow();

  @override
  ConsumerState<_OfflineSttModelsNavRow> createState() =>
      _OfflineSttModelsNavRowState();
}

class _OfflineSttModelsNavRowState
    extends ConsumerState<_OfflineSttModelsNavRow> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(offlineDictationServiceProvider).refreshStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(offlineDictationServiceProvider);
    final models = service.models;
    if (models.isEmpty) return const SizedBox.shrink();
    final selectedId = ref.watch(
      settingsNotifierProvider.select((s) => s.sttModelId),
    );
    final active = OfflineSttCatalog.byId(selectedId) ??
        OfflineSttCatalog.defaultModel;

    return ValueListenableBuilder<Map<String, OfflineSttStatus>>(
      valueListenable: service.statuses,
      builder: (context, statuses, _) {
        final l10n = AppLocalizations.of(context);
        final statusStrings = DownloadStatusStrings(
          ready: l10n.voiceDownloadStatusReady,
          downloading: l10n.voiceDownloadStatusDownloading,
          failed: l10n.voiceDownloadStatusFailed,
          notDownloaded: l10n.voiceDownloadStatusNotDownloaded,
          failedRetrySuffix: l10n.voiceDownloadFailedRetrySuffix,
          notDownloadedSuffix: l10n.voiceDownloadNotDownloadedSuffix,
        );
        final status =
            statuses[active.id] ?? OfflineSttStatus.notDownloaded;
        final readyCount = statuses.values
            .where((s) => s == OfflineSttStatus.ready)
            .length;
        final subtitle = StringBuffer(active.displayName)
          ..write(' · ')
          ..write(downloadStatusLabel(
            ready: status == OfflineSttStatus.ready,
            downloading: status == OfflineSttStatus.downloading,
            failed: status == OfflineSttStatus.failed,
            strings: statusStrings,
          ));
        if (readyCount > 0) {
          subtitle.write(' · $readyCount ${l10n.voiceInstalledLabel}');
        }
        return SettingsNavRow(
          icon: Icons.mic_none_outlined,
          title: l10n.voiceDictationModelsTitle,
          subtitle: subtitle.toString(),
          onTap: () => context.pushNamed('offline-stt-models'),
        );
      },
    );
  }
}
