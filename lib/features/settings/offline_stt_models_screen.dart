import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/offline_dictation_service.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/voice_status_subtitles.dart';

/// Manage downloadable offline speech-to-text models for dictation.
///
/// Lists every model in [OfflineSttCatalog], shows per-model download
/// status, and lets the user download, delete, and pick the active
/// model. Active selection is persisted as `Settings.sttModelId`.
class OfflineSttModelsScreen extends ConsumerStatefulWidget {
  const OfflineSttModelsScreen({super.key});

  @override
  ConsumerState<OfflineSttModelsScreen> createState() =>
      _OfflineSttModelsScreenState();
}

class _OfflineSttModelsScreenState
    extends ConsumerState<OfflineSttModelsScreen> {
  OfflineDictationService get _service =>
      ref.read(offlineDictationServiceProvider);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await _service.refreshStatuses();
      if (!mounted) return;
      // Auto-download the selected model when the picker opens so
      // the user does not hit a multi-minute wait on first mic use.
      final selectedId =
          ref.read(settingsNotifierProvider).sttModelId ??
          OfflineSttCatalog.defaultModel.id;
      final status = _service.statusFor(selectedId);
      if (status == OfflineSttStatus.ready ||
          status == OfflineSttStatus.downloading) {
        return;
      }
      final model = OfflineSttCatalog.byId(selectedId) ??
          OfflineSttCatalog.defaultModel;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Downloading ${model.displayName}'
            '${model.sizeLabel.isEmpty ? '' : ' (${model.sizeLabel})'}…',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      try {
        await _service.ensureModel(model.id);
        if (!mounted) return;
        messenger?.showSnackBar(
          SnackBar(content: Text('${model.displayName} ready')),
        );
      } catch (e) {
        if (!mounted) return;
        final detail = _service.errorFor(model.id) ?? e;
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Download failed: $detail'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaitedSafe(_download(model)),
            ),
          ),
        );
      }
    });
  }

  Future<void> _download(OfflineSttModel model) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.ensureModel(model.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Downloaded ${model.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      final detail = _service.errorFor(model.id) ?? e;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $detail'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaitedSafe(_download(model)),
          ),
        ),
      );
    }
  }

  Future<void> _delete(OfflineSttModel model) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${model.displayName}?'),
        content: const Text(
          'The model files will be removed from this device. '
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
      await _service.deleteModel(model.id);
      if (!mounted) return;
      final selected = ref.read(settingsNotifierProvider).sttModelId;
      if (selected == model.id) {
        await ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('sttModelId', null);
        _service.selectModel(null);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _select(OfflineSttModel model) async {
    await ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting('sttModelId', model.id);
    _service.selectModel(model.id);
  }

  @override
  Widget build(BuildContext context) {
    final models = _service.models;
    final selectedId = ref.watch(
      settingsNotifierProvider.select((s) => s.sttModelId),
    );
    final activeId =
        selectedId ?? OfflineSttCatalog.defaultModel.id;

    // Group by tier so the picker reads Fast / Balanced / Quality.
    final grouped = <String, List<OfflineSttModel>>{};
    for (final model in models) {
      grouped.putIfAbsent(model.tier, () => <OfflineSttModel>[]).add(model);
    }
    const tierOrder = ['fast', 'balanced', 'quality'];
    final tiers = [
      ...tierOrder.where(grouped.containsKey),
      ...grouped.keys.where((t) => !tierOrder.contains(t)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dictation models')),
      body: ValueListenableBuilder<Map<String, OfflineSttStatus>>(
        valueListenable: _service.statuses,
        builder: (context, statuses, _) {
          return ValueListenableBuilder<
              Map<String, OfflineSttDownloadProgress>>(
            valueListenable: _service.progress,
            builder: (context, progress, _) {
              return ListView(
                padding: AppScreenPadding.settings,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Tap a model to select it. The first download per '
                      "model fetches the archive from sherpa-onnx's "
                      'GitHub release. First mic use also downloads the '
                      'selected model if needed.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  for (final tier in tiers) ...[
                    SettingsSection(
                      title: _tierLabel(tier),
                      uppercase: false,
                      children: [
                        for (final model in grouped[tier]!)
                          _ModelRow(
                            model: model,
                            status: statuses[model.id] ??
                                OfflineSttStatus.notDownloaded,
                            progress: progress[model.id],
                            lastError: _service.errorFor(model.id),
                            isSelected: model.id == activeId,
                            onSelect: () => _select(model),
                            onDownload: () => _download(model),
                            onDelete: () => _delete(model),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _tierLabel(String tier) {
  switch (tier) {
    case 'fast':
      return 'Fast';
    case 'balanced':
      return 'Balanced';
    case 'quality':
      return 'Quality';
    default:
      return tier;
  }
}

/// Keep the first line short enough for a list subtitle.
String? _shortErrorDetail(Object? error) {
  final err = error?.toString();
  if (err == null || err.isEmpty) return null;
  return err.length > 90 ? '${err.substring(0, 90)}…' : err;
}

void unawaitedSafe(Future<void> future) {
  // Local helper so we don't import dart:async just for unawaited.
  future.ignore();
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.status,
    required this.isSelected,
    required this.onSelect,
    required this.onDownload,
    required this.onDelete,
    this.progress,
    this.lastError,
  });

  final OfflineSttModel model;
  final OfflineSttStatus status;
  final OfflineSttDownloadProgress? progress;
  final Object? lastError;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isReady = status == OfflineSttStatus.ready;
    final isDownloading = status == OfflineSttStatus.downloading;
    final isFailed = status == OfflineSttStatus.failed;

    final subtitle = StringBuffer(model.languages);
    if (model.sizeLabel.isNotEmpty) {
      subtitle.write(' · ${model.sizeLabel}');
    }
    final l10n = AppLocalizations.of(context);
    subtitle.write(downloadStatusSuffix(
      ready: isReady,
      downloading: isDownloading,
      failed: isFailed,
      strings: DownloadStatusStrings(
        ready: l10n.voiceDownloadStatusReady,
        downloading: l10n.voiceDownloadStatusDownloading,
        failed: l10n.voiceDownloadStatusFailed,
        notDownloaded: l10n.voiceDownloadStatusNotDownloaded,
        failedRetrySuffix: l10n.voiceDownloadFailedRetrySuffix,
        notDownloadedSuffix: l10n.voiceDownloadNotDownloadedSuffix,
      ),
      failureDetail: _shortErrorDetail(lastError),
      downloadingLabel: progress?.label,
    ));

    final IconData leadingIcon;
    final Color? leadingColor;
    if (isDownloading) {
      leadingIcon = Icons.downloading;
      leadingColor = cs.primary;
    } else if (isReady) {
      leadingIcon = Icons.mic;
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
      final fraction = progress?.fraction;
      trailing = SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: fraction,
          color: cs.primary,
        ),
      );
    } else if (isReady) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

    final row = SettingsRow(
      icon: leadingIcon,
      iconColor: leadingColor,
      title: model.displayName,
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

    if (!isDownloading) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg + 40,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress?.fraction,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }
}
