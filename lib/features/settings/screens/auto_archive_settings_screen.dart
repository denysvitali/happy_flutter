import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/local_settings.dart';
import '../../../core/services/auto_archive_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Settings screen for configuring auto-archive behavior.
class AutoArchiveSettingsScreen extends StatefulWidget {
  const AutoArchiveSettingsScreen({super.key});

  @override
  State<AutoArchiveSettingsScreen> createState() =>
      _AutoArchiveSettingsScreenState();
}

class _AutoArchiveSettingsScreenState
    extends State<AutoArchiveSettingsScreen> {
  late AutoArchiveSettings _settings;
  final _service = AutoArchiveService.instance;

  @override
  void initState() {
    super.initState();
    _settings = _service.getSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.autoArchiveTitle),
      ),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          SettingsSection(
            title: l10n.autoArchiveSection,
            children: [
              _DayPickerRow(
                title: l10n.autoArchiveAfterDays,
                subtitle: l10n.autoArchiveAfterDaysDesc,
                value: _settings.autoArchiveAfterDays,
                onChanged: (v) => _update(
                  _settings.copyWith(autoArchiveAfterDays: v),
                ),
              ),
              _DayPickerRow(
                title: l10n.autoArchiveIdleAfterDays,
                subtitle: l10n.autoArchiveIdleAfterDaysDesc,
                value: _settings.autoArchiveIdleAfterDays,
                onChanged: (v) => _update(
                  _settings.copyWith(autoArchiveIdleAfterDays: v),
                ),
              ),
              SettingsToggleRow(
                icon: Icons.power_settings_new_outlined,
                title: l10n.autoArchiveOnClose,
                subtitle: l10n.autoArchiveOnCloseDesc,
                value: _settings.autoArchiveOnAppClose,
                onChanged: (v) => _update(
                  _settings.copyWith(autoArchiveOnAppClose: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _update(AutoArchiveSettings newSettings) {
    setState(() => _settings = newSettings);
    _service.updateSettings(newSettings);
  }
}

class _DayPickerRow extends StatelessWidget {
  const _DayPickerRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int? value;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<int?>(
        value: value,
        underline: const SizedBox(),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(l10n.autoArchiveDisabled),
          ),
          for (final days in [7, 14, 30, 60, 90])
            DropdownMenuItem<int?>(
              value: days,
              child: Text('$days ${l10n.autoArchiveDays}'),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
