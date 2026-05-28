import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/ml/gemma_model_config.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/smart_features_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Settings screen for configuring on-device smart features (Gemma).
class SmartFeaturesSettingsScreen extends ConsumerStatefulWidget {
  const SmartFeaturesSettingsScreen({super.key});

  @override
  ConsumerState<SmartFeaturesSettingsScreen> createState() =>
      _SmartFeaturesSettingsScreenState();
}

class _SmartFeaturesSettingsScreenState
    extends ConsumerState<SmartFeaturesSettingsScreen> {
  final _service = SmartFeaturesService.instance;

  late bool _smartFeaturesEnabled;
  late bool _semanticSearchEnabled;
  late bool _autoTagsEnabled;

  bool _modelDownloaded = false;
  bool _checkingModel = true;
  double? _downloadProgress;
  bool _downloadFailed = false;
  StreamSubscription<double>? _downloadSub;

  final _testController = TextEditingController();
  bool _testRunning = false;
  String? _testError;
  List<String>? _testResults;

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
    _testController.dispose();
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

  Future<void> _runTest() async {
    final query = _testController.text.trim();
    if (query.isEmpty || _testRunning) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _testRunning = true;
      _testError = null;
      _testResults = null;
    });

    try {
      // Rank the most recent sessions by relevance to the query using the
      // real on-device model (same path used by semantic search).
      final all = ref.read(sessionsNotifierProvider).values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final candidates = all.take(20).toList();

      if (candidates.isEmpty) {
        setState(() {
          _testRunning = false;
          _testError = 'No sessions to rank yet.';
        });
        return;
      }

      final ranked = await _service.sessionRanker.rankSessions(
        query,
        candidates,
      );
      if (!mounted) return;
      setState(() {
        _testRunning = false;
        _testResults = ranked
            .take(5)
            .map(_sessionLabel)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testRunning = false;
        _testError = '$e';
      });
    }
  }

  String _sessionLabel(Session s) {
    final name = (s.metadata?.name ?? '').trim();
    if (name.isNotEmpty) return name;
    final path = (s.metadata?.path ?? '').trim();
    if (path.isNotEmpty) return path;
    return s.id;
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
          const SizedBox(height: AppSpacing.lg),
          _buildTesterSection(context),
        ],
      ),
    );
  }

  Widget _buildTesterSection(BuildContext context) {
    final ready = _smartFeaturesEnabled && _modelDownloaded;
    return SettingsSection(
      title: 'Try it',
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ready
                    ? 'Type a query and the on-device model will rank your '
                          'recent sessions by relevance.'
                    : 'Enable smart features and download the model to try '
                          'on-device ranking.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _testController,
                enabled: ready && !_testRunning,
                decoration: const InputDecoration(
                  hintText: 'e.g. flutter chat bug',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runTest(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: (ready && !_testRunning) ? _runTest : null,
                  icon: _testRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_testRunning ? 'Running…' : 'Run'),
                ),
              ),
              if (_testError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _testError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (_testResults != null) ...[
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _testResults!.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(
                      '${i + 1}. ${_testResults![i]}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
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
