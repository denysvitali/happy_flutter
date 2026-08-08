import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart' show SyncDomain;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/sync/sync_subscription_mixin.dart';
import 'widgets/artifact_pane_header.dart';

/// Screen showing detail view for a single artifact.
class ArtifactDetailScreen extends ConsumerStatefulWidget {
  const ArtifactDetailScreen({
    required this.artifactId,
    this.embedded = false,
    this.onClose,
    this.onEdit,
    super.key,
  });

  final String artifactId;

  /// When true, this widget is rendered inside a master-detail pane and
  /// must not provide its own [Scaffold]/[AppBar].
  final bool embedded;

  /// Invoked when the user taps the close action in embedded mode.
  final VoidCallback? onClose;

  /// Invoked when the user taps the edit action in embedded mode.
  ///
  /// When null (or in non-embedded mode), the edit action falls back to
  /// route-based navigation.
  final VoidCallback? onEdit;

  @override
  ConsumerState<ArtifactDetailScreen> createState() =>
      _ArtifactDetailScreenState();
}

class _ArtifactDetailScreenState extends ConsumerState<ArtifactDetailScreen>
    with SyncSubscriptionMixin {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(artifactsNotifierProvider.notifier).refreshFromSync();
    });
    subscribeToDomains([SyncDomain.artifacts], () {
      ref.read(artifactsNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artifact = ref.watch(
      artifactsNotifierProvider.select((a) => a[widget.artifactId]),
    );

    if (artifact == null) {
      final emptyBody = AppEmptyState(
        icon: Icons.error_outline,
        title: l10n.errorNotFound,
      );
      if (widget.embedded) {
        return Column(
          children: [
            ArtifactPaneHeader(
              title: l10n.artifactsDetail,
              onClose: widget.onClose,
            ),
            Expanded(child: emptyBody),
          ],
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(l10n.artifactsDetail)),
        body: emptyBody,
      );
    }

    final headerTitle = (artifact.title?.isNotEmpty ?? false)
        ? artifact.title!
        : artifact.id;

    final cs = Theme.of(context).colorScheme;
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: l10n.commonEdit,
        onPressed: () {
          if (widget.embedded && widget.onEdit != null) {
            widget.onEdit!();
          } else {
            context.push('/artifacts/${artifact.id}/edit');
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.delete_outline, color: cs.error),
        tooltip: l10n.commonDelete,
        onPressed: () => _confirmDelete(context, l10n, artifact),
      ),
    ];

    final body = SingleChildScrollView(
      padding: AppScreenPadding.standard,
      child: _ArtifactDetailBody(artifact: artifact),
    );

    if (widget.embedded) {
      return Column(
        children: [
          ArtifactPaneHeader(
            title: headerTitle,
            onClose: widget.onClose,
            actions: actions,
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(headerTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: body,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    DecryptedArtifact artifact,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.commonDelete,
      content: l10n.artifactsDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );

    if (confirmed) {
      if (!context.mounted) return;
      // Hoist the messenger before navigating away — this screen is
      // unmounted by the time a failed delete needs to surface feedback.
      final messenger = ScaffoldMessenger.of(context);
      // Leave the screen immediately — the notifier removes the artifact
      // optimistically and restores it (with a warning log) on failure.
      if (widget.embedded) {
        widget.onClose?.call();
      } else {
        safePop<void>(context, fallbackRouteName: 'artifacts');
      }
      final deleted = await ref
          .read(artifactsNotifierProvider.notifier)
          .optimisticRemove(artifact.id);
      if (!deleted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.artifactsFailedToDelete)),
        );
      }
    }
  }
}

class _ArtifactDetailBody extends ConsumerWidget {
  const _ArtifactDetailBody({required this.artifact});

  final DecryptedArtifact artifact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(artifact.createdAt);
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(artifact.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metadata card.
        _MetadataCard(
          rows: [
            _MetaRow(
              label: context.l10n.commonId,
              value: artifact.id,
              monospace: true,
            ),
            _MetaRow(
              label: context.l10n.commonCreated,
              value: _formatDateTime(createdAt),
            ),
            _MetaRow(
              label: context.l10n.commonUpdated,
              value: _formatDateTime(updatedAt),
            ),
            _MetaRow(
              label: context.l10n.commonSequence,
              value: artifact.seq.toString(),
            ),
            if (artifact.draft ?? false)
              _MetaRow(
                label: context.l10n.artifactsStatus,
                value: context.l10n.artifactsDraft,
              ),
          ],
        ),
        if (artifact.sessions?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(
            title: context.l10n.artifactsSourceSessions,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.l10n.artifactsSourceSessionsSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final sessionId in artifact.sessions!)
                  _ArtifactSessionRow(
                    sessionId: sessionId,
                    title: _sessionTitle(
                      ref
                          .watch(sessionsNotifierProvider)[sessionId]
                          ?.metadata
                          ?.name,
                      sessionId,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(
          title: context.l10n.artifactsContentLabel,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ContentBlock(artifact: artifact),
      ],
    );
  }

  static String _sessionTitle(String? name, String id) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final preview = id.length > 8 ? id.substring(0, 8) : id;
    return 'Session $preview';
  }

  static String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$m';
  }
}

class _ArtifactSessionRow extends StatelessWidget {
  const _ArtifactSessionRow({required this.sessionId, required this.title});

  final String sessionId;
  final String title;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: AppTouchTarget.comfortable,
    leading: const Icon(Icons.chat_bubble_outline),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      sessionId,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'monospace'),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        context.pushNamed('chat', pathParameters: {'sessionId': sessionId}),
  );
}

// ─── Metadata card ───────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.rows});

  final List<_MetaRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(
                height: AppBorder.thin,
                thickness: AppBorder.hairline,
                color: cs.outlineVariant.withValues(alpha: AppOpacity.half),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: AppLineHeight.normal,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      height: AppLineHeight.normal,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Content block ───────────────────────────────────────────────────────────

class _ContentBlock extends StatefulWidget {
  const _ContentBlock({required this.artifact});

  final DecryptedArtifact artifact;

  @override
  State<_ContentBlock> createState() => _ContentBlockState();
}

class _ContentBlockState extends State<_ContentBlock> {
  bool _copied = false;

  Future<void> _copyToClipboard(String text) async {
    await setClipboardTextSafely(text);
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasBody = widget.artifact.body?.isNotEmpty ?? false;
    final bodyText = hasBody
        ? widget.artifact.body!
        : '[Encrypted content — decryption not yet implemented]';

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar row.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  'text',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (hasBody)
                  _CopyButton(
                    copied: _copied,
                    onTap: () => _copyToClipboard(bodyText),
                  ),
              ],
            ),
          ),
          Divider(
            height: AppBorder.thin,
            thickness: AppBorder.hairline,
            color: cs.outlineVariant.withValues(alpha: AppOpacity.half),
          ),
          // Content.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(
              bodyText,
              style: hasBody
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: AppLineHeight.loose,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant,
                      height: AppLineHeight.normal,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              copied ? Icons.check : Icons.copy_outlined,
              size: 18,
              color: copied ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              copied ? context.l10n.commonDone : context.l10n.commonCopy,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: copied ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
