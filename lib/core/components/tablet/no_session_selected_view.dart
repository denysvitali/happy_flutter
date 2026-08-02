import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../theme/app_tokens.dart';
import '../app_empty_state.dart';

/// Detail-pane placeholder shown in the tablet/desktop split layout when no
/// session is selected.
///
/// Replaces the bare skeleton the chat pane used to show: it names the state
/// ("No session selected"), explains what to do next, and offers the same
/// "New Session" action as the list pane so the empty half of the screen is
/// actionable rather than dead space.
class NoSessionSelectedView extends StatelessWidget {
  const NoSessionSelectedView({super.key, this.onCreateSession});

  /// Invoked by the call-to-action button. The button is hidden when null.
  final VoidCallback? onCreateSession;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onCreate = onCreateSession;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoint.sidebarMax),
          child: AppEmptyState(
            icon: Icons.forum_outlined,
            title: l10n.sessionsNoSessionSelected,
            subtitle: l10n.sessionsNoSessionSelectedHint,
            action: onCreate == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.sessionNewSession),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
