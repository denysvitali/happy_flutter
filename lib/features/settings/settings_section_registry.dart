import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/components/settings_section.dart';

// ─── Search normalization ────────────────────────────────────────────────────

/// Normalizes text for settings search: lowercase with whitespace runs
/// collapsed to single spaces. Every hub match — queries, titles, row
/// labels and static term lists — goes through this one function.
String normalizeSettingsSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Splits [query] into normalized AND tokens. Returns an empty list for
/// a blank query (meaning "no filtering").
List<String> settingsSearchTokens(String query) {
  final normalized = normalizeSettingsSearchText(query);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ');
}

bool _containsToken(String haystack, String token) =>
    normalizeSettingsSearchText(haystack).contains(token);

// ─── Row specs ───────────────────────────────────────────────────────────────

/// Declarative description of a single row inside a settings section.
///
/// The hub renders rows from specs via [buildSettingsSection] and
/// matches searches against [searchText] before any widget is built,
/// so filtered-out rows never enter the element tree.
sealed class SettingsRowSpec {
  const SettingsRowSpec();

  /// Raw searchable text for this row (title + subtitle + extras).
  String get searchText;
}

/// A `SettingsToggleRow` bound to a settings key.
class ToggleRowSpec extends SettingsRowSpec {
  const ToggleRowSpec({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  String get searchText => subtitle == null ? title : '$title $subtitle';
}

/// A `SettingsNavRow` that pushes a named route on tap.
class NavRouteRowSpec extends SettingsRowSpec {
  const NavRouteRowSpec({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String route;
  final String? subtitle;

  /// When false the row renders disabled (`onTap == null`).
  final bool enabled;

  @override
  String get searchText => subtitle == null ? title : '$title $subtitle';
}

/// A `SettingsNavRow` that opens an external URL on tap.
class UrlLaunchRowSpec extends SettingsRowSpec {
  const UrlLaunchRowSpec({
    required this.icon,
    required this.title,
    required this.url,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String url;
  final String? subtitle;

  @override
  String get searchText => subtitle == null ? title : '$title $subtitle';
}

/// A `SettingsNavRow` whose tap runs an arbitrary action (dialog,
/// bottom sheet) instead of a route navigation.
class ActionNavRowSpec extends SettingsRowSpec {
  const ActionNavRowSpec({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  String get searchText => subtitle == null ? title : '$title $subtitle';
}

/// A row rendered by a caller-supplied builder — used for widgets that
/// are not row primitives (InlineThemePicker, ProfileSwitcherTile).
///
/// The searchable text comes from [searchTerms]; pass the widget's own
/// visible labels there so search keeps matching what is on screen.
class CustomWidgetRowSpec extends SettingsRowSpec {
  const CustomWidgetRowSpec({required this.build, this.searchTerms = const []});

  final WidgetBuilder build;
  final List<String> searchTerms;

  @override
  String get searchText => searchTerms.join(' ');
}

// ─── Section spec ────────────────────────────────────────────────────────────

/// Declarative description of one titled card in the settings hub.
class SettingsSectionSpec {
  const SettingsSectionSpec({
    required this.title,
    required this.rows,
    this.description,
  });

  final String title;
  final String? description;
  final List<SettingsRowSpec> rows;

  SettingsSectionSpec withRows(List<SettingsRowSpec> rows) =>
      SettingsSectionSpec(title: title, description: description, rows: rows);
}

/// Renders [spec] as a `SettingsSection` of primitive rows.
Widget buildSettingsSection(BuildContext context, SettingsSectionSpec spec) {
  return SettingsSection(
    title: spec.title,
    description: spec.description,
    children: [for (final row in spec.rows) _buildSpecRow(context, row)],
  );
}

Widget _buildSpecRow(BuildContext context, SettingsRowSpec spec) {
  return switch (spec) {
    ToggleRowSpec(
      :final icon,
      :final title,
      :final subtitle,
      :final value,
      :final onChanged,
    ) =>
      SettingsToggleRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
      ),
    NavRouteRowSpec(
      :final icon,
      :final title,
      :final subtitle,
      :final route,
      :final enabled,
    ) =>
      SettingsNavRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: enabled ? () => context.pushNamed(route) : null,
      ),
    UrlLaunchRowSpec(:final icon, :final title, :final url, :final subtitle) =>
      SettingsNavRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () => _launchExternalUrl(url),
      ),
    ActionNavRowSpec(
      :final icon,
      :final title,
      :final subtitle,
      :final onTap,
    ) =>
      SettingsNavRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ),
    CustomWidgetRowSpec(:final build) => build(context),
  };
}

Future<void> _launchExternalUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ─── Filtering ───────────────────────────────────────────────────────────────

/// Filters [spec] down to the rows matching every token in [tokens].
///
/// Rules:
/// - a blank token list returns the spec untouched;
/// - if the section title alone matches every token, the full row list
///   is kept (the user asked for the section);
/// - otherwise only rows matching every token render, falling back to
///   rows matching at least one token when the tokens span several rows;
/// - sections with nothing matching return null and are dropped.
SettingsSectionSpec? filterSettingsSection(
  SettingsSectionSpec spec,
  List<String> tokens,
) {
  if (tokens.isEmpty) return spec;
  if (tokens.every((token) => _containsToken(spec.title, token))) {
    return spec;
  }
  final allTokenRows = spec.rows
      .where((row) => tokens.every((t) => _containsToken(row.searchText, t)))
      .toList();
  if (allTokenRows.isNotEmpty) return spec.withRows(allTokenRows);
  final anyTokenRows = spec.rows
      .where((row) => tokens.any((t) => _containsToken(row.searchText, t)))
      .toList();
  if (anyTokenRows.isEmpty) return null;
  return spec.withRows(anyTokenRows);
}

// ─── Hub entries ─────────────────────────────────────────────────────────────

/// One top-level block of the settings hub.
///
/// Implementations decide visibility for the current [tokens] at data
/// level, so filtered-out blocks never build widgets.
sealed class SettingsHubEntry {
  const SettingsHubEntry();

  /// Builds this entry, or returns null when [tokens] filter it out.
  Widget? buildFor(BuildContext context, List<String> tokens);
}

/// A hub entry backed by a [SettingsSectionSpec].
class SpecSectionEntry extends SettingsHubEntry {
  const SpecSectionEntry(this.spec);

  final SettingsSectionSpec spec;

  @override
  Widget? buildFor(BuildContext context, List<String> tokens) {
    final visible = filterSettingsSection(spec, tokens);
    if (visible == null || visible.rows.isEmpty) return null;
    return buildSettingsSection(context, visible);
  }
}

/// A hand-built block (status summary, workflow presets) that is not
/// row-spec shaped; it is matched as a whole against a fixed term list
/// and shown or hidden entirely.
class StaticBlockEntry extends SettingsHubEntry {
  const StaticBlockEntry({required this.widget, required this.searchTerms});

  final Widget widget;
  final List<String> searchTerms;

  @override
  Widget? buildFor(BuildContext context, List<String> tokens) {
    if (tokens.isEmpty) return widget;
    final blob = normalizeSettingsSearchText(searchTerms.join(' '));
    return tokens.every(blob.contains) ? widget : null;
  }
}
