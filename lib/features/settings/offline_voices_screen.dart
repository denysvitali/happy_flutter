import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/settings_section.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/offline_tts_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_tokens.dart';

/// Manage downloadable Piper voices for offline TTS.
///
/// Lists every voice in [TtsService.offlineVoices], shows per-voice
/// download status, and lets the user download, delete, preview, and
/// pick the active voice. The active selection is persisted as
/// `Settings.ttsVoiceId`.
class OfflineVoicesScreen extends ConsumerStatefulWidget {
  const OfflineVoicesScreen({super.key});

  @override
  ConsumerState<OfflineVoicesScreen> createState() =>
      _OfflineVoicesScreenState();
}

class _OfflineVoicesScreenState extends ConsumerState<OfflineVoicesScreen> {
  @override
  void initState() {
    super.initState();
    // Walk the cache once so each row paints with the right initial
    // state (downloaded vs. not).
    Future<void>.microtask(() {
      TtsService().refreshOfflineVoiceStatuses();
    });
  }

  Future<void> _download(OfflineTtsModel voice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TtsService().ensureOfflineVoice(voice.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Downloaded ${voice.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _delete(OfflineTtsModel voice) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${voice.displayName}?'),
        content: Text(
          'The voice files will be removed from this device. '
          'You can re-download them at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await TtsService().deleteOfflineVoice(voice.id);
      if (!mounted) return;
      // If the deleted voice was selected, fall back to the default.
      final selected = ref.read(settingsNotifierProvider).ttsVoiceId;
      if (selected == voice.id) {
        await ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('ttsVoiceId', null);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _select(OfflineTtsModel voice) async {
    await ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting('ttsVoiceId', voice.id);
    TtsService().selectOfflineVoice(voice.id);
  }

  Future<void> _preview(OfflineTtsModel voice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TtsService().init();
      await TtsService().speak(
        // Localized-ish sample. Sherpa-onnx will pronounce English
        // text reasonably for any locale; users primarily judge
        // voice timbre here.
        'Hello! This is the ${voice.displayName} voice.',
        useOffline: true,
        offlineVoiceId: voice.id,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Preview failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voices = TtsService().offlineVoices;
    final selectedId =
        ref.watch(settingsNotifierProvider.select((s) => s.ttsVoiceId));
    final activeId = selectedId ??
        (voices.isNotEmpty ? voices.first.id : '');

    // Group by locale so the picker reads "all the English ones,
    // then German, then …".
    final grouped = <String, List<OfflineTtsModel>>{};
    for (final voice in voices) {
      grouped.putIfAbsent(voice.locale, () => <OfflineTtsModel>[]).add(voice);
    }
    final locales = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Offline voices')),
      body: ValueListenableBuilder<Map<String, OfflineTtsStatus>>(
        valueListenable: TtsService().offlineVoiceStatuses,
        builder: (context, statuses, _) {
          return ListView(
            padding: AppScreenPadding.settings,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'Tap a voice to select it. The first download per '
                  "voice fetches the model from sherpa-onnx's GitHub "
                  'release.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final locale in locales) ...[
                SettingsSection(
                  title: _localeLabel(locale),
                  uppercase: false,
                  children: [
                    for (final voice in grouped[locale]!)
                      _VoiceRow(
                        voice: voice,
                        status: statuses[voice.id] ??
                            OfflineTtsStatus.notDownloaded,
                        isSelected: voice.id == activeId,
                        onSelect: () => _select(voice),
                        onDownload: () => _download(voice),
                        onDelete: () => _delete(voice),
                        onPreview: () => _preview(voice),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Map a locale code like `en_US` to a friendly section header.
String _localeLabel(String locale) {
  switch (locale) {
    case 'en_US':
      return 'English (United States)';
    case 'en_GB':
      return 'English (United Kingdom)';
    case 'de_DE':
      return 'German';
    case 'fr_FR':
      return 'French';
    case 'es_ES':
      return 'Spanish';
    case 'it_IT':
      return 'Italian';
    case 'pt_BR':
      return 'Portuguese (Brazil)';
    case 'nl_NL':
      return 'Dutch';
    case 'pl_PL':
      return 'Polish';
    case 'ru_RU':
      return 'Russian';
    case 'ca_ES':
      return 'Catalan';
    default:
      return locale;
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.voice,
    required this.status,
    required this.isSelected,
    required this.onSelect,
    required this.onDownload,
    required this.onDelete,
    required this.onPreview,
  });

  final OfflineTtsModel voice;
  final OfflineTtsStatus status;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isReady = status == OfflineTtsStatus.ready;
    final isDownloading = status == OfflineTtsStatus.downloading;
    final isFailed = status == OfflineTtsStatus.failed;

    final subtitle = StringBuffer()
      ..write(voice.gender == 'F'
          ? 'Female'
          : voice.gender == 'M'
              ? 'Male'
              : 'Voice');
    if (voice.quality.isNotEmpty) {
      subtitle.write(' · ${voice.quality}');
    }
    if (voice.sizeLabel.isNotEmpty) {
      subtitle.write(' · ${voice.sizeLabel}');
    }
    if (isFailed) {
      subtitle.write(' · download failed, tap retry');
    } else if (isDownloading) {
      subtitle.write(' · downloading…');
    } else if (!isReady) {
      subtitle.write(' · not downloaded');
    }

    final IconData leadingIcon;
    final Color? leadingColor;
    if (isDownloading) {
      leadingIcon = Icons.downloading;
      leadingColor = cs.primary;
    } else if (isReady) {
      leadingIcon = Icons.record_voice_over;
      leadingColor = isSelected ? cs.primary : null;
    } else if (isFailed) {
      leadingIcon = Icons.error_outline;
      leadingColor = cs.error;
    } else {
      leadingIcon = Icons.cloud_download_outlined;
      leadingColor = null;
    }

    Widget trailing;
    if (isDownloading) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (isReady) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.play_arrow),
            onPressed: onPreview,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(
                Icons.check_circle_rounded,
                size: AppSpacing.xl,
                color: cs.primary,
              ),
            ),
        ],
      );
    } else {
      trailing = IconButton(
        tooltip: isFailed ? 'Retry download' : 'Download',
        icon: Icon(isFailed ? Icons.refresh : Icons.cloud_download_outlined),
        onPressed: onDownload,
      );
    }

    return SettingsRow(
      icon: leadingIcon,
      iconColor: leadingColor,
      title: voice.displayName,
      subtitle: subtitle.toString(),
      trailing: trailing,
      onTap: () {
        if (isReady) {
          onSelect();
        } else if (!isDownloading) {
          onDownload();
        }
      },
    );
  }
}
