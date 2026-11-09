import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/utils/session_utils.dart';

/// Layouts the sessions tab can render, keyed by their persisted
/// `sessionsViewStyle` setting value.
enum SessionsViewStyle {
  missionControl('mission_control', Icons.space_dashboard_outlined),
  statusBoard('status', Icons.view_agenda_outlined),
  machines('machines', Icons.dns_outlined),
  agent('agent', Icons.smart_toy_outlined),
  recent('recent', Icons.history),
  kubernetes('kubernetes', Icons.cloud_outlined),
  folder('folder', Icons.folder_outlined),
  repository('repository', Icons.source_outlined),
  unreadFocus('unread_focus', Icons.mark_chat_unread_outlined);

  const SessionsViewStyle(this.wire, this.icon);

  /// Persisted setting value.
  final String wire;
  final IconData icon;

  /// Workspace grouping for folder-style layouts; null for other layouts.
  SessionGrouping? get workspaceGrouping => switch (this) {
    folder => SessionGrouping.folder,
    repository => SessionGrouping.repository,
    _ => null,
  };

  /// Sectioned board layouts rendered by `SessionBoardView`.
  bool get isBoard => switch (this) {
    statusBoard || machines || agent || recent || kubernetes => true,
    _ => false,
  };

  /// Unknown values fall back to Mission Control, the setting default.
  static SessionsViewStyle fromWire(String value) {
    for (final style in values) {
      if (style.wire == value) return style;
    }
    return missionControl;
  }

  String label(AppLocalizations l10n) => switch (this) {
    missionControl => l10n.sessionsViewStyleMissionControl,
    statusBoard => l10n.sessionsViewStyleStatusBoard,
    machines => l10n.sessionsViewStyleMachines,
    agent => l10n.sessionsViewStyleAgent,
    recent => l10n.sessionsViewStyleRecent,
    kubernetes => l10n.sessionsViewStyleKubernetes,
    folder => l10n.sessionsViewStyleFolderCentric,
    repository => l10n.sessionsViewStyleRepository,
    unreadFocus => l10n.sessionsViewStyleUnreadFocus,
  };

  String description(AppLocalizations l10n) => switch (this) {
    missionControl => l10n.sessionsViewStyleMissionControlHint,
    statusBoard => l10n.sessionsViewStyleStatusBoardHint,
    machines => l10n.sessionsViewStyleMachinesHint,
    agent => l10n.sessionsViewStyleAgentHint,
    recent => l10n.sessionsViewStyleRecentHint,
    kubernetes => l10n.sessionsViewStyleKubernetesHint,
    folder => l10n.sessionsViewStyleFolderCentricHint,
    repository => l10n.sessionsViewStyleRepositoryHint,
    unreadFocus => l10n.sessionsViewStyleUnreadFocusHint,
  };
}
