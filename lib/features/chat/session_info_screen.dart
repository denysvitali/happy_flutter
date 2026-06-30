import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/sessions_api.dart';
import '../../core/components/app_section_header.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/safe_pop.dart';
import '../../core/utils/session_utils.dart';
import 'session_debug_export.dart';
import 'widgets/session_info_widgets.dart';

// Minimum CLI version required for full compatibility.
const _minimumCliVersion = '0.10.0';

// Reusable thin divider used inside the metadata/info cards.
const _kRowDivider = Divider(
  height: 1,
  thickness: AppBorder.hairline,
  indent: 52,
);

/// Compares two semver strings.
/// Returns -1, 0, or 1 (like compareTo).
int _compareVersions(String v1, String v2) {
  String clean(String v) => v.split('-')[0];
  final p1 = clean(v1).split('.').map(int.tryParse).toList();
  final p2 = clean(v2).split('.').map(int.tryParse).toList();
  final len = p1.length > p2.length ? p1.length : p2.length;
  for (var i = 0; i < len; i++) {
    final a = i < p1.length ? (p1[i] ?? 0) : 0;
    final b = i < p2.length ? (p2[i] ?? 0) : 0;
    if (a > b) return 1;
    if (a < b) return -1;
  }
  return 0;
}

/// Returns true if [version] >= [minimum].
bool _isVersionSupported(String version) {
  try {
    return _compareVersions(version, _minimumCliVersion) >= 0;
  } catch (_) {
    return false;
  }
}

/// Screen that shows detailed info about a specific session.
class SessionInfoScreen extends ConsumerWidget {
  /// Creates a [SessionInfoScreen] for the given [sessionId].
  const SessionInfoScreen({
    required this.sessionId,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// The session ID to display info for.
  final String sessionId;

  /// When true, render as a pane inside a tablet master-detail layout.
  /// Skips the outer [Scaffold]/[AppBar] and uses a thin in-pane header.
  final bool embedded;

  /// Called when the in-pane close button is tapped (embedded only).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      sessionsNotifierProvider.select((s) => s[sessionId]),
    );
    final title = context.l10n.sessionInfoTitle;

    if (session == null) {
      return _InfoShell(
        title: title,
        embedded: embedded,
        onClose: onClose,
        body: Center(child: Text(context.l10n.sessionInfoNotFound)),
      );
    }

    return _InfoShell(
      title: title,
      embedded: embedded,
      onClose: onClose,
      body: _SessionInfoBody(session: session, embedded: embedded),
    );
  }
}

/// Wraps [body] in a [Scaffold] (route mode) or a thin in-pane header +
/// body column (embedded mode for tablet master-detail).
class _InfoShell extends StatelessWidget {
  const _InfoShell({
    required this.title,
    required this.body,
    required this.embedded,
    this.onClose,
  });

  final String title;
  final Widget body;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: AppBorder.hairline,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  // TODO(i18n): close tooltip not yet localized
                  tooltip: 'Close',
                  onPressed: onClose,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _SessionInfoBody extends ConsumerStatefulWidget {
  const _SessionInfoBody({required this.session, this.embedded = false});

  final Session session;
  final bool embedded;

  @override
  ConsumerState<_SessionInfoBody> createState() => _SessionInfoBodyState();
}

class _SessionInfoBodyState extends ConsumerState<_SessionInfoBody> {
  bool _isArchiving = false;
  bool _isDeleting = false;

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFlavor(String? flavor, AppLocalizations l10n) {
    if (flavor == null) return l10n.commonUnknown;
    if (flavor == 'claude') return 'Claude';
    if (flavor == 'gpt' || flavor == 'openai') return 'Codex';
    if (flavor == 'gemini') return 'Gemini';
    if (flavor == 'pi') return 'pi';
    if (flavor == 'opencode') return 'OpenCode';
    return flavor;
  }

  Future<void> _copyToClipboard(
    String text, {
    String? message,
    int maxBytes = defaultClipboardMaxBytes,
  }) async {
    final result = await setClipboardTextSafely(text, maxBytes: maxBytes);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final copiedMessage = message ?? l10n.sessionInfoCopied;
    final snackBarMessage = result.success
        ? _clipboardSuccessMessage(copiedMessage, result.truncated)
        : l10n.textSelectionFailedToCopy;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackBarMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _clipboardSuccessMessage(String message, bool truncated) =>
      truncated ? '$message (truncated)' : message;

  Future<void> _exportDebugInfo() async {
    await _copyToClipboard(
      buildSessionDebugExportText(widget.session),
      message: AppLocalizations.of(context).sessionInfoDebugExportCopied,
      maxBytes: sessionDebugExportClipboardMaxBytes,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: cs.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleArchiveSession() async {
    final failedArchiveMsg = context.l10n.sessionsFailedToArchive;
    final sessionId = widget.session.id;
    final embedded = widget.embedded;
    final api = SessionsApi();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.sessionsArchiveSession),
          content: Text(l10n.sessionsArchiveConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.sessionsArchive),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isArchiving = true);
    try {
      await api.setSessionArchived(sessionId, true);
      await ref
          .read(sessionsNotifierProvider.notifier)
          .markSessionArchived(sessionId, true);
      if (!mounted) return;
      if (!embedded) {
        safePop<void>(context);
      }
    } catch (e, st) {
      logger.error(
        'Failed to archive session from info screen: '
        'sessionId=$sessionId',
        e,
        st,
      );
      _showError(failedArchiveMsg);
    } finally {
      if (mounted) setState(() => _isArchiving = false);
    }
  }

  Future<void> _handleDeleteSession() async {
    final failedDeleteMsg = context.l10n.sessionsFailedToDelete;
    final sessionId = widget.session.id;
    final embedded = widget.embedded;
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.chatDeleteSession),
          content: Text(l10n.sessionsDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isDeleting = true);
    final deleted = await sessionsNotifier.optimisticDelete(sessionId);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (deleted) {
      if (!embedded) {
        safePop<void>(context);
      }
    } else {
      _showError(failedDeleteMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final session = widget.session;
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final meta = session.metadata;

    final isOnline = session.presence == 'online';
    final hasMachineAction = meta?.machineId != null;
    final hasArchiveAction = isOnline;
    final hasDeleteAction = !session.active;
    final isCliOutdated =
        meta?.version != null && !_isVersionSupported(meta!.version!);

    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.computer_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  sessionName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  sessionSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusChip(isActive: session.isOnline),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // CLI Version Outdated Warning
        if (isCliOutdated) ...[
          Card(
            elevation: 0,
            color: theme.colorScheme.tertiaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.colorScheme.tertiary, width: 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => _copyToClipboard(
                'npm install -g happy-coder@latest',
                message: l10n.sessionInfoUpdateCommandCopied,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: theme.colorScheme.onTertiaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sessionInfoCliOutdated,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Run: npm install -g happy-coder@latest',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.copy_outlined,
                      color: theme.colorScheme.onTertiaryContainer,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        AppSectionHeader(
          title: l10n.sessionInfoSectionDetails,
          uppercase: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.fingerprint,
                label: l10n.sessionInfoLabelSessionId,
                value: session.id.length > 16
                    ? '${session.id.substring(0, 8)}...'
                          '${session.id.substring(session.id.length - 8)}'
                    : session.id,
                onTap: () => _copyToClipboard(session.id),
              ),
              _kRowDivider,
              InfoRow(
                icon: Icons.access_time,
                label: l10n.sessionInfoLabelCreated,
                value: _formatDate(session.createdAt),
              ),
              _kRowDivider,
              InfoRow(
                icon: Icons.update,
                label: l10n.sessionInfoLabelLastUpdated,
                value: _formatDate(session.updatedAt),
              ),
              _kRowDivider,
              InfoRow(
                icon: Icons.tag,
                label: l10n.sessionInfoLabelSequence,
                value: session.seq.toString(),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: l10n.sessionInfoSectionQuickActions,
          uppercase: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              ActionRow(
                icon: Icons.bug_report_outlined,
                label: l10n.sessionInfoActionExportDebug,
                color: theme.colorScheme.primary,
                onTap: _exportDebugInfo,
              ),
              if (hasMachineAction || hasArchiveAction || hasDeleteAction)
                _kRowDivider,
              if (hasMachineAction) ...[
                ActionRow(
                  icon: Icons.dns_outlined,
                  label: l10n.sessionInfoActionViewMachine,
                  color: theme.colorScheme.primary,
                  onTap: () => context.push('/machine/${meta!.machineId}'),
                ),
              ],
              if (hasMachineAction && (hasArchiveAction || hasDeleteAction))
                _kRowDivider,
              if (hasArchiveAction)
                ActionRow(
                  icon: Icons.archive_outlined,
                  label: l10n.sessionInfoActionArchive,
                  color: theme.colorScheme.error,
                  isLoading: _isArchiving,
                  onTap: _isArchiving ? null : _handleArchiveSession,
                ),
              if (hasArchiveAction && hasDeleteAction) _kRowDivider,
              if (hasDeleteAction)
                ActionRow(
                  icon: Icons.delete_outline,
                  label: l10n.sessionInfoActionDelete,
                  color: theme.colorScheme.error,
                  isLoading: _isDeleting,
                  onTap: _isDeleting ? null : _handleDeleteSession,
                ),
            ],
          ),
        ),

        if (meta != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: l10n.sessionInfoSectionMetadata,
            uppercase: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.computer,
                  label: l10n.sessionInfoLabelHost,
                  value: meta.host,
                ),
                if (meta.path != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.folder_outlined,
                    label: l10n.sessionInfoLabelPath,
                    value: formatPathRelativeToHome(
                      meta.path!,
                      homeDir: meta.homeDir,
                    ),
                  ),
                ],
                if (meta.machineId != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.dns_outlined,
                    label: l10n.sessionInfoLabelMachineId,
                    value: meta.machineId!,
                    onTap: () => _copyToClipboard(meta.machineId!),
                  ),
                ],
                if (meta.os != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.memory,
                    label: l10n.sessionInfoLabelOs,
                    value: formatOSPlatform(meta.os),
                  ),
                ],
                if (meta.version != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: isCliOutdated
                        ? Icons.warning_amber_outlined
                        : Icons.verified_outlined,
                    label: l10n.sessionInfoLabelCliVersion,
                    value: meta.version!,
                    iconColor: isCliOutdated
                        ? theme.colorScheme.tertiary
                        : null,
                  ),
                ],
                if (meta.flavor != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.auto_awesome,
                    label: l10n.sessionInfoLabelAiProvider,
                    value: _formatFlavor(meta.flavor, l10n),
                  ),
                ],
                if (meta.claudeSessionId != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.code_outlined,
                    label: l10n.sessionInfoLabelClaudeSessionId,
                    value: () {
                      final id = meta.claudeSessionId!;
                      return '${id.substring(0, 8)}...'
                          '${id.substring(id.length - 8)}';
                    }(),
                    onTap: () => _copyToClipboard(meta.claudeSessionId!),
                  ),
                ],
                if (meta.hostPid != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.terminal,
                    label: l10n.sessionInfoLabelProcessId,
                    value: meta.hostPid!.toString(),
                  ),
                ],
                if (meta.happyHomeDir != null) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.home_outlined,
                    label: l10n.sessionInfoLabelHappyHome,
                    value: formatPathRelativeToHome(
                      meta.happyHomeDir!,
                      homeDir: meta.homeDir,
                    ),
                  ),
                ],
                _kRowDivider,
                ActionRow(
                  icon: Icons.copy_outlined,
                  label: l10n.sessionInfoActionCopyMetadata,
                  color: theme.colorScheme.primary,
                  onTap: () {
                    _copyToClipboard(
                      jsonEncode(meta.toJson()),
                      message: l10n.sessionInfoMetadataCopied,
                    );
                  },
                ),
              ],
            ),
          ),
        ],

        if (session.agentState != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: l10n.sessionInfoSectionAgentState,
            uppercase: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.person_outline,
                  label: l10n.sessionInfoLabelControlledByUser,
                  value: (session.agentState!.controlledByUser ?? false)
                      ? l10n.commonYes
                      : l10n.commonNo,
                ),
                if (session.agentState!.requests != null &&
                    session.agentState!.requests!.isNotEmpty) ...[
                  _kRowDivider,
                  InfoRow(
                    icon: Icons.hourglass_empty_outlined,
                    label: l10n.sessionInfoLabelPendingRequests,
                    value: session.agentState!.requests!.length.toString(),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: l10n.sessionInfoSectionActivity,
          uppercase: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.lightbulb_outline,
                label: l10n.sessionInfoLabelThinking,
                value: session.thinking ? l10n.commonYes : l10n.commonNo,
                iconColor: session.thinking
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (session.thinking && session.thinkingAt != null) ...[
                _kRowDivider,
                InfoRow(
                  icon: Icons.timer_outlined,
                  label: l10n.sessionInfoLabelThinkingSince,
                  value: _formatDate(session.thinkingAt!),
                  iconColor: theme.colorScheme.tertiary,
                ),
              ],
            ],
          ),
        ),

        if (meta?.tools != null && meta!.tools!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: l10n.sessionInfoSectionTools,
            uppercase: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: meta.tools!.map((tool) {
                  return Chip(
                    label: Text(
                      tool,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: AppFontSize.sm,
                      ),
                    ),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}
