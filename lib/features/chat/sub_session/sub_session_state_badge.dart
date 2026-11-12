import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import 'sub_session_projection.dart';

/// Lookup progress for a child that is not in the session store.
enum SubSessionLookup { idle, loading, unavailable }

/// Localized label for [state]; [lookup] refines the not-loaded case.
String subSessionChildStateLabel(
  AppLocalizations l10n,
  SubSessionChildState state, {
  SubSessionLookup lookup = SubSessionLookup.idle,
}) {
  return switch (state) {
    SubSessionChildState.notLoaded => switch (lookup) {
      SubSessionLookup.loading => l10n.subSessionStateLoading,
      SubSessionLookup.unavailable => l10n.subSessionStateUnavailable,
      SubSessionLookup.idle => l10n.subSessionStateNotLoaded,
    },
    SubSessionChildState.starting => l10n.subSessionStateStarting,
    SubSessionChildState.working => l10n.subSessionStateWorking,
    SubSessionChildState.idle => l10n.subSessionStateIdle,
    SubSessionChildState.offline => l10n.subSessionStateOffline,
    SubSessionChildState.stopped => l10n.subSessionStateStopped,
    SubSessionChildState.archived => l10n.subSessionStateArchived,
  };
}

/// Semantic tone for [state].
AppBadgeTone subSessionChildStateTone(SubSessionChildState state) {
  return switch (state) {
    SubSessionChildState.working ||
    SubSessionChildState.starting => AppBadgeTone.info,
    SubSessionChildState.idle => AppBadgeTone.success,
    SubSessionChildState.stopped => AppBadgeTone.danger,
    _ => AppBadgeTone.neutral,
  };
}

/// Pill showing the live state of a child session.
class SubSessionStateBadge extends StatelessWidget {
  const SubSessionStateBadge({
    required this.state,
    super.key,
    this.lookup = SubSessionLookup.idle,
  });

  final SubSessionChildState state;
  final SubSessionLookup lookup;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: subSessionChildStateLabel(context.l10n, state, lookup: lookup),
      tone: subSessionChildStateTone(state),
      showToneIcon: false,
    );
  }
}
