part of 'settings_screen.dart';

/// Top-level URL launcher shared by [_DataSectionSpec] (which is part
/// of this library and cannot access instance methods) and the
/// `_SettingsScreenState.openUrl` instance method.
Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Declarative spec for a single row inside a [SettingsSection].
///
/// Used by the four data-shaped section builders (About, Account,
/// Developer, Machines) to express their child list as data instead
/// of a hand-written `_buildXSection` method. The remaining sections
/// (Appearance, Behavior, Voice, Tools, Sessions) use custom widgets,
/// dialogs, or per-row dynamic content and continue to use the
/// method-based builders.
sealed class _SettingsRowSpec {
  const _SettingsRowSpec();
}

/// A `SettingsNavRow` that pushes a named route on tap.
class _NavRouteSpec extends _SettingsRowSpec {
  const _NavRouteSpec({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String route;
  final String? subtitle;
}

/// A `SettingsNavRow` that opens a URL on tap.
class _NavUrlSpec extends _SettingsRowSpec {
  const _NavUrlSpec({
    required this.icon,
    required this.title,
    required this.url,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String url;
  final String? subtitle;
}

/// Declarative spec for a section that can be rendered from data alone.
class _DataSectionSpec {
  const _DataSectionSpec({
    required this.title,
    required this.rows,
  });
  final String title;
  final List<_SettingsRowSpec> rows;

  /// Build the [SettingsSection] widget from this spec.
  Widget build(BuildContext context) {
    return SettingsSection(
      title: title,
      children: [
        for (final row in rows) _buildRow(context, row),
      ],
    );
  }

  Widget _buildRow(BuildContext context, _SettingsRowSpec spec) {
    return switch (spec) {
      _NavRouteSpec(
        :final icon,
        :final title,
        :final route,
        :final subtitle,
      ) =>
        SettingsNavRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: () => context.pushNamed(route),
        ),
      _NavUrlSpec(:final icon, :final title, :final url, :final subtitle) =>
        SettingsNavRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: () => _openExternalUrl(url),
        ),
    };
  }
}

// ─── Data-driven section spec factories ─────────────────────────────────────
//
// The four sections below used to be hand-written `_buildXSection`
// methods of ~20-30 lines each. Each just returned a `SettingsSection`
// with one or more `SettingsNavRow` children. They are now a single
// expression each that the renderer above turns into the same widget
// tree.

// About section — 4 URL-launching rows (GitHub, issues, privacy, terms).
_DataSectionSpec _aboutSectionSpec(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return _DataSectionSpec(
    title: l10n.settingsAbout,
    rows: [
      _NavUrlSpec(
        icon: Icons.code,
        title: l10n.settingsGitHub,
        url: AppConfig.githubUrl,
        subtitle: AppConfig.githubSlug,
      ),
      _NavUrlSpec(
        icon: Icons.bug_report_outlined,
        title: l10n.settingsReportIssue,
        url: AppConfig.githubIssuesUrl,
      ),
      _NavUrlSpec(
        icon: Icons.privacy_tip_outlined,
        title: l10n.settingsPrivacyPolicy,
        url: AppConfig.privacyUrl,
      ),
      _NavUrlSpec(
        icon: Icons.gavel_outlined,
        title: l10n.settingsTermsOfService,
        url: AppConfig.termsUrl,
      ),
    ],
  );
}

// Account section — 1 row pushing the 'account' route.
_DataSectionSpec _accountSectionSpec(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return _DataSectionSpec(
    title: l10n.settingsAccount,
    rows: [
      _NavRouteSpec(
        icon: Icons.person,
        title: l10n.accountAccountSettings,
        subtitle: l10n.settingsAccountSubtitle,
        route: 'account',
      ),
    ],
  );
}

// Developer section — 1 row pushing the 'developer' route; subtitle
// depends on whether developer mode is enabled.
_DataSectionSpec _developerSectionSpec(
  BuildContext context, {
  required bool developerModeEnabled,
}) {
  final l10n = AppLocalizations.of(context);
  return _DataSectionSpec(
    title: l10n.settingsDeveloper,
    rows: [
      _NavRouteSpec(
        icon: Icons.build,
        title: l10n.settingsDeveloperOptions,
        subtitle: developerModeEnabled
            ? l10n.settingsDeveloperEnabled
            : l10n.settingsDeveloperTapToEnable,
        route: 'developer',
      ),
    ],
  );
}

// Machines section — 1 row pushing the 'machines' route. Caller is
// responsible for gating the section (the parent `_buildSearchSections`
// only emits this section when `machineStats.total > 0`).
_DataSectionSpec _machinesSectionSpec(
  BuildContext context, {
  required String? firstMachineSubtitle,
}) {
  final l10n = AppLocalizations.of(context);
  return _DataSectionSpec(
    title: l10n.settingsMachines,
    rows: [
      _NavRouteSpec(
        icon: Icons.computer_outlined,
        title: l10n.settingsMachines,
        subtitle: firstMachineSubtitle,
        route: 'machines',
      ),
      _NavRouteSpec(
        icon: Icons.extension_outlined,
        title: l10n.settingsMcpServers,
        subtitle: l10n.settingsMcpServersSubtitle,
        route: 'mcp-servers',
      ),
    ],
  );
}
