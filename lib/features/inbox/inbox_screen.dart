import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/services/inbox_state_storage.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/tab_bar/tab_bar.dart' show AppTab;
import '../../core/utils/snack.dart';
import 'inbox_providers.dart';
import 'widgets/inbox_list_tile.dart';
import 'widgets/inbox_thread_view.dart';

/// Width of the message list beside an open thread on wide screens.
const double _kInboxListWidth = 380;

/// The agent Inbox: high-priority messages from every session, laid out
/// like a mail client — a message list, and on wide screens the open
/// thread beside it. Phones open a thread as its own screen.
class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  InboxFolder _folder = InboxFolder.inbox;
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inboxCatalogProvider).items;
    final states = ref.watch(inboxStateProvider);
    InboxMessageState stateOf(InboxItem i) =>
        states[i.key] ?? InboxMessageState.initial;
    final visible = [
      for (final item in items)
        if (stateOf(item).done == (_folder == InboxFolder.done)) item,
    ];
    final openCount = items.where((i) => !stateOf(i).done).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoint.desktop;
        InboxItem? selected;
        if (wide) {
          for (final item in visible) {
            if (item.key == _selectedKey) selected = item;
          }
        }
        final list = _InboxList(
          folder: _folder,
          openCount: openCount,
          items: visible,
          states: states,
          selectedKey: wide ? selected?.key : null,
          onFolderChanged: (folder) => setState(() {
            _folder = folder;
            _selectedKey = null;
          }),
          onOpen: (item) {
            if (wide) {
              setState(() => _selectedKey = item.key);
            } else {
              context.pushNamed(
                'inbox-message',
                pathParameters: {
                  'sessionId': item.sessionId,
                  'messageId': item.message.id,
                },
              );
            }
          },
        );
        if (!wide) return list;
        final cs = Theme.of(context).colorScheme;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _kInboxListWidth,
              child: ColoredBox(color: cs.surfaceContainerLow, child: list),
            ),
            VerticalDivider(width: 1, color: cs.outlineVariant),
            Expanded(
              child: selected == null
                  ? _EmptyPane(
                      icon: Icons.mark_email_read_outlined,
                      title: context.l10n.inboxSelectMessage,
                    )
                  : InboxThreadView(
                      key: ValueKey<String>(selected.key),
                      item: selected,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _InboxList extends ConsumerWidget {
  const _InboxList({
    required this.folder,
    required this.openCount,
    required this.items,
    required this.states,
    required this.selectedKey,
    required this.onFolderChanged,
    required this.onOpen,
  });

  final InboxFolder folder;
  final int openCount;
  final List<InboxItem> items;
  final Map<String, InboxMessageState> states;
  final String? selectedKey;
  final ValueChanged<InboxFolder> onFolderChanged;
  final ValueChanged<InboxItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final cs = theme.colorScheme;
    final notifier = ref.read(inboxStateProvider.notifier);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.inboxTitle, style: AppText.screenTitle(theme)),
                const SizedBox(height: AppSpacing.xxs),
                Text(l10n.inboxSubtitle, style: AppText.secondary(theme)),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<InboxFolder>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: InboxFolder.inbox,
                      icon: const Icon(Icons.inbox_outlined),
                      label: Text(
                        openCount > 0
                            ? '${l10n.inboxFolderInbox} · $openCount'
                            : l10n.inboxFolderInbox,
                      ),
                    ),
                    ButtonSegment(
                      value: InboxFolder.done,
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(l10n.inboxFolderDone),
                    ),
                  ],
                  selected: {folder},
                  onSelectionChanged: (s) => onFolderChanged(s.first),
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: folder == InboxFolder.inbox
                ? _EmptyPane(
                    icon: Icons.mark_email_read_outlined,
                    title: l10n.inboxEmptyTitle,
                    body: l10n.inboxEmptyBody,
                  )
                : _EmptyPane(
                    icon: Icons.done_all_rounded,
                    title: l10n.inboxDoneEmptyTitle,
                    body: l10n.inboxDoneEmptyBody,
                  ),
          )
        else
          SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: AppSpacing.lg + AppAvatarSize.medium + AppSpacing.md,
              color: cs.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final state = states[item.key] ?? InboxMessageState.initial;
              return Dismissible(
                key: ValueKey<String>('inbox:${item.key}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  color: cs.primaryContainer,
                  child: Icon(
                    state.done
                        ? Icons.move_to_inbox_rounded
                        : Icons.done_rounded,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                onDismissed: (_) {
                  final done = !state.done;
                  notifier.setDone(item.key, done: done);
                  if (done) {
                    context.showSnack(
                      l10n.inboxMarkedDone,
                      replaceCurrent: true,
                      action: SnackBarAction(
                        label: l10n.inboxUndo,
                        onPressed: () =>
                            notifier.setDone(item.key, done: false),
                      ),
                    );
                  }
                },
                child: InboxListTile(
                  item: item,
                  state: state,
                  selected: item.key == selectedKey,
                  onTap: () => onOpen(item),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppAvatarSize.large, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title(theme),
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppText.secondary(theme),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single Inbox thread as its own screen (phones and notification taps).
class InboxMessageScreen extends ConsumerWidget {
  const InboxMessageScreen({
    required this.sessionId,
    required this.messageId,
    super.key,
  });

  final String sessionId;
  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = inboxMessageKey(sessionId, messageId);
    final items = ref.watch(inboxCatalogProvider).items;
    InboxItem? item;
    for (final candidate in items) {
      if (candidate.key == key) item = candidate;
    }
    final state = ref.watch(
      inboxStateProvider.select((s) => s[key] ?? InboxMessageState.initial),
    );
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _close(context)),
        title: Text(l10n.inboxTitle),
        actions: [
          if (item != null)
            InboxMessageActions(
              item: item,
              state: state,
              onDone: () => _close(context),
            ),
        ],
      ),
      body: item == null
          ? _EmptyPane(
              icon: Icons.mark_email_read_outlined,
              title: l10n.inboxMessageMissing,
            )
          : InboxThreadView(item: item, showHeaderActions: false),
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      safePop(context);
    } else {
      // Opened from a notification: land on the Inbox tab, not Sessions.
      context.go('/?tab=${AppTab.inbox.name}');
    }
  }
}
