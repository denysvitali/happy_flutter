import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/sessions_api.dart';
import '../../core/components/app_section_header.dart';
import '../../core/components/tablet/embedded_pane.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_color_scheme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/session_utils.dart';
import '../../core/utils/version_utils.dart';
import 'session_debug_export.dart';
import 'widgets/session_info_widgets.dart';

// Reusable thin divider used inside the metadata/info cards.
const _kRowDivider = Divider(
  height: 1,
  thickness: AppBorder.hairline,
  indent: 52,
);

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
      return EmbeddedPaneShell(
        title: title,
        embedded: embedded,
        onClose: onClose,
        body: Center(child: Text(context.l10n.sessionInfoNotFound)),
      );
    }

    return EmbeddedPaneShell(
      title: title,
      embedded: embedded,
      onClose: onClose,
      body: _SessionInfoBody(session: session, embedded: embedded),
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
  SessionPod? _pod;
  SessionPodLogsResponse? _podLogs;
  bool _podLoading = false;
  bool _podActionRunning = false;
  Object? _podError;

  @override
  void initState() {
    super.initState();
    if (widget.session.isKubernetesSession) {
      Future<void>.microtask(_refreshPod);
    }
  }

  Future<void> _refreshPod({bool loadLogs = false}) async {
    final machineId = widget.session.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) return;
    setState(() {
      _podLoading = true;
      _podError = null;
    });
    try {
      final pod = await sync.machineGetSessionPod(
        machineId: machineId,
        sessionId: widget.session.id,
      );
      SessionPodLogsResponse? logs;
      if (loadLogs) {
        logs = await sync.machineGetSessionPodLogs(
          machineId: machineId,
          sessionId: widget.session.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _pod = pod;
        if (logs != null) _podLogs = logs;
      });
    } catch (error, stack) {
      logger.warning('Failed to load session pod', error, stack);
      if (mounted) setState(() => _podError = error);
    } finally {
      if (mounted) setState(() => _podLoading = false);
    }
  }

  Future<void> _runPodAction(String action) async {
    final machineId = widget.session.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) return;
    setState(() {
      _podActionRunning = true;
      _podError = null;
    });
    try {
      final response = switch (action) {
        'pause' => await sync.machinePauseSessionPod(
          machineId: machineId,
          sessionId: widget.session.id,
        ),
        'resume' => await sync.machineResumeSessionPod(
          machineId: machineId,
          sessionId: widget.session.id,
        ),
        _ => await sync.machineKillSessionPod(
          machineId: machineId,
          sessionId: widget.session.id,
        ),
      };
      if (!response.success) throw StateError(response.message);
      if (!mounted) return;
      setState(() => _pod = response.pod ?? _pod);
      await _refreshPod(loadLogs: _podLogs != null);
    } catch (error, stack) {
      logger.warning('Session pod action failed: $action', error, stack);
      if (mounted) setState(() => _podError = error);
    } finally {
      if (mounted) setState(() => _podActionRunning = false);
    }
  }

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
    if (flavor == 'grok' || flavor == 'grok-build') return l10n.sessionsGrok;
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
      await ref
          .read(sessionsNotifierProvider.notifier)
          .markSessionArchived(sessionId, true);
      await api.setSessionArchived(sessionId, true);
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
        meta?.version != null && !isVersionSupported(meta!.version!);

    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusChip(isActive: session.isOnline),
                    if (meta != null) SessionSandboxBadge(metadata: meta),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (session.isKubernetesSession) ...[
          AppSectionHeader(title: l10n.sessionPodSection, uppercase: true),
          const SizedBox(height: AppSpacing.sm),
          _SessionPodCard(
            session: session,
            pod: _pod,
            logs: _podLogs,
            loading: _podLoading,
            actionRunning: _podActionRunning,
            error: _podError,
            onRefresh: () => _refreshPod(loadLogs: _podLogs != null),
            onLoadLogs: () => _refreshPod(loadLogs: true),
            onPause: () => _runPodAction('pause'),
            onResume: () => _runPodAction('resume'),
            onKill: () => _runPodAction('kill'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

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
            side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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
            side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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
              side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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
              side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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
            side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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
              side: BorderSide(
              color:
                  (theme.extension<AppColorScheme>() ??
                          AppColorScheme.dark())
                      .glassBorder,
            ),
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

class _SessionPodCard extends StatelessWidget {
  const _SessionPodCard({
    required this.session,
    required this.pod,
    required this.logs,
    required this.loading,
    required this.actionRunning,
    required this.error,
    required this.onRefresh,
    required this.onLoadLogs,
    required this.onPause,
    required this.onResume,
    required this.onKill,
  });

  final Session session;
  final SessionPod? pod;
  final SessionPodLogsResponse? logs;
  final bool loading;
  final bool actionRunning;
  final Object? error;
  final VoidCallback onRefresh;
  final VoidCallback onLoadLogs;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onKill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currentPod = pod;
    final state = currentPod == null
        ? session.podDisplayState
        : currentPod.archived
        ? SessionPodDisplayState.archived
        : currentPod.paused
        ? SessionPodDisplayState.paused
        : currentPod.ready
        ? SessionPodDisplayState.ready
        : currentPod.phase.toLowerCase() == 'failed'
        ? SessionPodDisplayState.failed
        : SessionPodDisplayState.scheduling;
    final stateLabel = switch (state) {
      SessionPodDisplayState.scheduling => l10n.sessionPodScheduling,
      SessionPodDisplayState.ready => l10n.sessionPodReady,
      SessionPodDisplayState.paused => l10n.sessionPodPaused,
      SessionPodDisplayState.archived => l10n.sessionPodArchived,
      SessionPodDisplayState.failed => l10n.sessionPodFailed,
    };

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_queue_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    currentPod?.podName ??
                        session.metadata?.podName ??
                        l10n.sessionPod,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Chip(label: Text(stateLabel)),
                IconButton(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if ((currentPod?.namespace ?? session.metadata?.namespace)
                    ?.isNotEmpty ==
                true)
              Text(
                currentPod?.namespace ?? session.metadata!.namespace!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (currentPod?.reason.isNotEmpty == true ||
                currentPod?.message.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                  currentPod!.reason,
                  currentPod.message,
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.sessionPodLoadFailed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : onLoadLogs,
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.sessionPodLogs),
                ),
                if (state == SessionPodDisplayState.paused)
                  FilledButton.tonalIcon(
                    onPressed: actionRunning ? null : onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.sessionPodResume),
                  )
                else if (state == SessionPodDisplayState.ready)
                  FilledButton.tonalIcon(
                    onPressed: actionRunning ? null : onPause,
                    icon: const Icon(Icons.pause),
                    label: Text(l10n.sessionPodPause),
                  ),
                FilledButton.tonalIcon(
                  onPressed: actionRunning ? null : onKill,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(l10n.sessionPodKill),
                ),
              ],
            ),
            if (logs != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                constraints: const BoxConstraints(maxHeight: 320),
                padding: const EdgeInsets.all(AppSpacing.md),
                color: theme.colorScheme.surfaceContainerHighest,
                child: SingleChildScrollView(
                  child: SelectableText(
                    logs!.content.isEmpty
                        ? l10n.sessionPodLogsEmpty
                        : logs!.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              if (logs!.truncated)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.sessionPodLogsTruncated,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
