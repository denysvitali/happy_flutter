import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_nesting.dart';
import '../../../core/utils/session_utils.dart';
import 'chat_chrome_density.dart';

/// Opens [sessionId]'s chat on top of the current route.
void openSessionChat(BuildContext context, String sessionId) {
  HapticFeedback.selectionClick();
  context.push('/chat/$sessionId');
}

/// Slim strip above a sub-session's transcript naming the session that
/// spawned it. Tapping opens the parent; hidden for top-level sessions.
class ParentSessionBanner extends ConsumerWidget {
  const ParentSessionBanner({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentId = ref.watch(
      sessionsNotifierProvider.select(
        (sessions) => sessions[sessionId]?.metadata?.parentSessionId,
      ),
    );
    if (parentId == null) return const SizedBox.shrink();
    final parentName = ref.watch(
      sessionsNotifierProvider.select((sessions) {
        final parent = sessions[parentId];
        return parent == null ? null : getSessionName(parent);
      }),
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final dense = ChatChromeScope.of(context).isDense;
    final label = parentName == null
        ? l10n.subSessionOfUnknown
        : l10n.subSessionOf(parentName);
    final canOpen = parentName != null;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? AppSpacing.xxs : AppSpacing.xs,
      ),
      child: Material(
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outlineVariant, width: AppBorder.hairline),
        ),
        child: Semantics(
          button: canOpen,
          hint: canOpen ? l10n.subSessionOpenParent : null,
          child: InkWell(
            key: const ValueKey('parent-session-banner'),
            onTap: canOpen ? () => openSessionChat(context, parentId) : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: dense ? AppSpacing.xxs : AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: AppIconSize.sm,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(theme, cs.onSurfaceVariant),
                    ),
                  ),
                  if (canOpen)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppIconSize.md,
                      color: cs.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Session Info sections linking a session to its parent and to the
/// sub-sessions its agent spawned. Renders nothing for unrelated sessions.
class SessionNestingSections extends ConsumerWidget {
  const SessionNestingSections({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentId = session.metadata?.parentSessionId;
    final parent = parentId == null
        ? null
        : ref.watch(sessionsNotifierProvider.select((s) => s[parentId]));
    final children = ref.watch(
      sessionsNotifierProvider.select(
        (s) => _SessionList(subSessionsOf(s, session.id)),
      ),
    );
    if (parentId == null && children.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    const gap = SizedBox(height: AppSpacing.xl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parentId != null) ...[
          gap,
          SettingsSection(
            title: l10n.sessionInfoSectionParent,
            children: [
              if (parent != null)
                SubSessionRow(session: parent)
              else
                ListTile(
                  leading: const Icon(Icons.subdirectory_arrow_right_rounded),
                  title: Text(l10n.subSessionOfUnknown),
                ),
            ],
          ),
        ],
        if (children.items.isNotEmpty) ...[
          gap,
          SettingsSection(
            title: l10n.sessionInfoSectionSubSessions,
            children: [
              for (final child in children.items)
                SubSessionRow(
                  key: ValueKey('sub-session-row-${child.id}'),
                  session: child,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Selector value comparing child lists by content, so unrelated catalog
/// updates do not rebuild Session Info.
@immutable
class _SessionList {
  const _SessionList(this.items);

  final List<Session> items;

  @override
  bool operator ==(Object other) =>
      other is _SessionList &&
      other.items.length == items.length &&
      Iterable<int>.generate(
        items.length,
      ).every((i) => identical(other.items[i], items[i]));

  @override
  int get hashCode => Object.hashAll(items.map(identityHashCode));
}

/// Display state of a linked session in Session Info.
enum SubSessionState { needsApproval, working, ready, offline, archived }

SubSessionState subSessionStateOf(Session session) {
  if (session.archived || !session.active) return SubSessionState.archived;
  if (session.presence != 'online') return SubSessionState.offline;
  if (session.agentState?.requests?.isNotEmpty ?? false) {
    return SubSessionState.needsApproval;
  }
  if (session.thinking) return SubSessionState.working;
  return SubSessionState.ready;
}

/// A linked session row: status dot, name, state, and a chevron to open it.
class SubSessionRow extends StatelessWidget {
  const SubSessionRow({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final app = theme.extension<AppColorScheme>();
    final l10n = context.l10n;
    final state = subSessionStateOf(session);
    final (label, color) = switch (state) {
      SubSessionState.needsApproval => (
        l10n.subSessionStateNeedsApproval,
        app?.warning ?? cs.error,
      ),
      SubSessionState.working => (l10n.subSessionStateWorking, cs.tertiary),
      SubSessionState.ready => (
        l10n.subSessionStateReady,
        app?.success ?? cs.primary,
      ),
      SubSessionState.offline => (
        l10n.subSessionStateOffline,
        cs.onSurfaceVariant,
      ),
      SubSessionState.archived => (
        l10n.subSessionStateArchived,
        cs.onSurfaceVariant,
      ),
    };
    final name = getSessionName(session);
    return Semantics(
      button: true,
      label: '$name, $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openSessionChat(context, session.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.comfortable,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: AppSpacing.sm),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        style: AppText.secondary(theme, color),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppSpacing.xl,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
