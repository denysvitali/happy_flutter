import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/ml/gemma_model_config.dart';
import '../../../core/services/smart_features_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Settings screen for configuring on-device smart features (Gemma).
class SmartFeaturesSettingsScreen extends StatefulWidget {
  const SmartFeaturesSettingsScreen({super.key});

  @override
  State<SmartFeaturesSettingsScreen> createState() =>
      _SmartFeaturesSettingsScreenState();
}

class _SmartFeaturesSettingsScreenState
    extends State<SmartFeaturesSettingsScreen> {
  final _service = SmartFeaturesService.instance;

  late bool _smartFeaturesEnabled;
  late bool _semanticSearchEnabled;
  late bool _autoTagsEnabled;

  bool _modelDownloaded = false;
  bool _checkingModel = true;
  double? _downloadProgress;
  bool _downloadFailed = false;
  StreamSubscription<double>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _smartFeaturesEnabled = _service.smartFeaturesEnabled;
    _semanticSearchEnabled = _service.semanticSearchEnabled;
    _autoTagsEnabled = _service.autoTagsEnabled;
    _refreshModelState();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshModelState() async {
    final downloaded = await _service.isModelDownloaded();
    if (!mounted) return;
    setState(() {
      _modelDownloaded = downloaded;
      _checkingModel = false;
    });
  }

  void _startDownload() {
    setState(() {
      _downloadProgress = 0;
      _downloadFailed = false;
    });
    _downloadSub?.cancel();
    _downloadSub = _service.downloadModel().listen(
      (p) {
        if (!mounted) return;
        setState(() => _downloadProgress = p);
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = null;
          _downloadFailed = true;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _downloadProgress = null;
          _modelDownloaded = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.smartFeaturesTitle),
      ),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          SettingsSection(
            title: l10n.smartFeaturesSection,
            children: [
              SettingsToggleRow(
                icon: Icons.auto_awesome,
                title: l10n.smartFeaturesEnabled,
                subtitle: l10n.smartFeaturesEnabledDesc,
                value: _smartFeaturesEnabled,
                onChanged: (v) {
                  setState(() => _smartFeaturesEnabled = v);
                  _service.setSmartFeaturesEnabled(v);
                },
              ),
              _StatusRow(
                isReady: _smartFeaturesEnabled && _modelDownloaded,
                readyLabel: l10n.smartFeaturesReady,
                unavailableLabel: l10n.smartFeaturesUnavailable,
                unavailableDesc: l10n.smartFeaturesUnavailableDesc,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.smartFeaturesModelSection,
            children: [_buildModelRow(context, l10n)],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.semanticSearchTitle,
            children: [
              SettingsToggleRow(
                icon: Icons.search,
                title: l10n.semanticSearchTitle,
                subtitle: l10n.semanticSearchDesc,
                value: _semanticSearchEnabled,
                onChanged: (v) {
                  if (!_smartFeaturesEnabled) return;
                  setState(() => _semanticSearchEnabled = v);
                  _service.setSemanticSearchEnabled(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.autoTagsTitle,
            children: [
              SettingsToggleRow(
                icon: Icons.label_outline,
                title: l10n.autoTagsTitle,
                subtitle: l10n.autoTagsDesc,
                value: _autoTagsEnabled,
                onChanged: (v) {
                  if (!_smartFeaturesEnabled) return;
                  setState(() => _autoTagsEnabled = v);
                  _service.setAutoTagsEnabled(v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelRow(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;

    if (_checkingModel) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(''),
      );
    }

    if (_downloadProgress != null) {
      final percent = (_downloadProgress! * 100).round();
      return ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: _downloadProgress == 0 ? null : _downloadProgress,
          ),
        ),
        title: Text(l10n.smartFeaturesDownloading(percent)),
        subtitle: LinearProgressIndicator(
          value: _downloadProgress == 0 ? null : _downloadProgress,
        ),
      );
    }

    if (_modelDownloaded) {
      return ListTile(
        leading: Icon(Icons.check_circle, color: Colors.green),
        title: Text(l10n.smartFeaturesModelReady),
      );
    }

    return ListTile(
      leading: Icon(
        _downloadFailed ? Icons.error_outline : Icons.download,
        color: _downloadFailed ? cs.error : cs.onSurfaceVariant,
      ),
      title: Text(l10n.smartFeaturesDownloadModel),
      subtitle: Text(
        _downloadFailed
            ? l10n.smartFeaturesDownloadFailed
            : l10n.smartFeaturesDownloadModelDesc(
                GemmaModelConfig.approxDownloadSize,
              ),
      ),
      onTap: _startDownload,
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.isReady,
    required this.readyLabel,
    required this.unavailableLabel,
    required this.unavailableDesc,
  });

  final bool isReady;
  final String readyLabel;
  final String unavailableLabel;
  final String unavailableDesc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isReady ? Icons.check_circle : Icons.warning_amber_rounded,
        color: isReady ? Colors.green : cs.onSurfaceVariant,
      ),
      title: Text(isReady ? readyLabel : unavailableLabel),
      subtitle: isReady ? null : Text(unavailableDesc),
    );
  }
}
