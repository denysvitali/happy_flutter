import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/smart_features_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Settings screen for configuring smart features (Gemma 2B).
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
  bool _isGemmaAvailable = false;

  @override
  void initState() {
    super.initState();
    _smartFeaturesEnabled = _service.smartFeaturesEnabled;
    _semanticSearchEnabled = _service.semanticSearchEnabled;
    _autoTagsEnabled = _service.autoTagsEnabled;
    _isGemmaAvailable = _service.sessionRanker.isAvailable;
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
                isAvailable: _isGemmaAvailable,
                readyLabel: l10n.smartFeaturesReady,
                unavailableLabel: l10n.smartFeaturesUnavailable,
                unavailableDesc: l10n.smartFeaturesUnavailableDesc,
              ),
            ],
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
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.isAvailable,
    required this.readyLabel,
    required this.unavailableLabel,
    required this.unavailableDesc,
  });

  final bool isAvailable;
  final String readyLabel;
  final String unavailableLabel;
  final String unavailableDesc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isAvailable ? Icons.check_circle : Icons.warning_amber_rounded,
        color: isAvailable ? Colors.green : cs.onSurfaceVariant,
      ),
      title: Text(isAvailable ? readyLabel : unavailableLabel),
      subtitle: isAvailable ? null : Text(unavailableDesc),
    );
  }
}
