import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/settings_section.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/offline_dictation_service.dart';
import '../../core/theme/app_tokens.dart';

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
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            duration: const Duration(seconds: 6),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          duration: const Duration(seconds: 6),
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
  });

  final OfflineSttModel model;
  final OfflineSttStatus status;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isReady = status == OfflineSttStatus.ready;
    final isDownloading = status == OfflineSttStatus.downloading;
    final isFailed = status == OfflineSttStatus.failed;

    final subtitle = StringBuffer(model.languages);
    if (model.sizeLabel.isNotEmpty) {
      subtitle.write(' · ${model.sizeLabel}');
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
  }
}
