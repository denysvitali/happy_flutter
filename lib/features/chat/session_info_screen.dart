import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/utils/clipboard_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/settings_section.dart';
import '../../core/components/tablet/embedded_pane.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/session_utils.dart';
import '../../core/utils/version_utils.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'session_debug_export.dart';
import 'widgets/session_info_widgets.dart';
import 'widgets/session_pod_section.dart';
import 'widgets/sub_session_links.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/components/app_banner.dart';
import '../../core/utils/snack.dart';

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
  SessionPod? _pod;
  SessionPodLogsResponse? _podLogs;
  bool _podLoading = false;
  Object? _podError;
  late final TextEditingController _startupResumeMessageController;
  late bool _startupResumeEnabled;
  bool _startupResumeSaving = false;

  @override
  void initState() {
    super.initState();
    _startupResumeEnabled =
        widget.session.metadata?.resumeOnDaemonStart ?? false;
    _startupResumeMessageController = TextEditingController(
      text: widget.session.metadata?.resumeOnDaemonStartMessage ?? 'continue',
    );
    if (widget.session.isKubernetesSession) {
      Future<void>.microtask(_refreshPod);
    }
  }

  @override
  void didUpdateWidget(covariant _SessionInfoBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMetadata = oldWidget.session.metadata;
    final metadata = widget.session.metadata;
    if (!_startupResumeSaving &&
        (oldMetadata?.resumeOnDaemonStart != metadata?.resumeOnDaemonStart ||
            oldMetadata?.resumeOnDaemonStartMessage !=
                metadata?.resumeOnDaemonStartMessage)) {
      _startupResumeEnabled = metadata?.resumeOnDaemonStart ?? false;
      _startupResumeMessageController.text =
          metadata?.resumeOnDaemonStartMessage ?? 'continue';
    }
  }

  @override
  void dispose() {
    _startupResumeMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveStartupResume() async {
    if (widget.session.metadata?.flavor == 'har') return;
    final metadata = widget.session.metadata;
    final machineId = metadata?.machineId;
    if (machineId == null || machineId.isEmpty) return;
    final message = _startupResumeMessageController.text.trim();
    if (_startupResumeEnabled && message.isEmpty) {
      _showError(context.l10n.sessionStartupResumeMessageRequired);
      return;
    }
    // Resolve localization before the RPC. The user can leave this screen
    // while it is pending, and a failed RPC must not look up inherited state
    // through a disposed BuildContext in the catch path.
    final saveFailedMessage = context.l10n.sessionStartupResumeSaveFailed;
    setState(() => _startupResumeSaving = true);
    try {
      await sync.machineSetSessionStartupResume(
        machineId: machineId,
        sessionId: widget.session.id,
        enabled: _startupResumeEnabled,
        message: message,
      );
      if (!mounted) return;
      context.showSnack(context.l10n.sessionStartupResumeSaved);
    } catch (error, stack) {
      logger.warning('Failed to update startup resume setting', error, stack);
      _showError(saveFailedMessage);
    } finally {
      if (mounted) setState(() => _startupResumeSaving = false);
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

  /// Records the pod action in the app-wide operation store, which syncs it
  /// to the daemon in the background; the section reflects its outcome.
  void _runPodAction(KubernetesPodAction action) {
    final machineId = widget.session.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) return;
    ref
        .read(podOperationsNotifierProvider.notifier)
        .submitAction(
          machineId: machineId,
          sessionId: widget.session.id,
          action: action,
        );
  }

  /// Applies a settled pod operation for this session: a success adopts the
  /// daemon's pod report and refreshes it.
  void _onPodOperation(PodOperation? previous, PodOperation? next) {
    if (previous == null || next == null || previous.id != next.id) return;
    if (!previous.isPending || !next.isSucceeded || !mounted) return;
    setState(() => _pod = next.pod ?? _pod);
    unawaited(_refreshPod(loadLogs: _podLogs != null));
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
    if (flavor == 'agy' || flavor == 'gemini') return 'AGY';
    if (flavor == 'pi') return 'pi';
    if (flavor == 'opencode') return 'OpenCode';
    if (flavor == 'prime-agent') return 'Prime Agent';
    if (flavor == 'grok' || flavor == 'grok-build') return l10n.sessionsGrok;
    return flavor;
  }

  Future<void> _copyToClipboard(
    String text, {
    String? message,
    int maxBytes = defaultClipboardMaxBytes,
  }) async {
    await copyWithFeedback(
      context,
      text,
      successMessage: message ?? AppLocalizations.of(context).sessionInfoCopied,
      maxBytes: maxBytes,
    );
  }

  Future<void> _exportDebugInfo() async {
    await _copyToClipboard(
      buildSessionDebugExportText(widget.session),
      message: AppLocalizations.of(context).sessionInfoDebugExportCopied,
      maxBytes: sessionDebugExportClipboardMaxBytes,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    context.showSnack(
      message,
      tone: SnackTone.error,
      duration: const Duration(seconds: 3),
    );
  }

  /// Archives in the background: the session leaves the list at once and a
  /// failure is reported app-wide with Retry, so the screen closes now.
  Future<void> _handleArchiveSession() async {
    final operations = ref.read(sessionOperationsNotifierProvider.notifier);
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionsArchiveSession,
      content: l10n.sessionsArchiveConfirm,
      confirmLabel: l10n.sessionsArchive,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    operations.archive(widget.session);
    if (!widget.embedded) safePop<void>(context);
  }

  /// Deletes in the background, like [_handleArchiveSession].
  Future<void> _handleDeleteSession() async {
    final operations = ref.read(sessionOperationsNotifierProvider.notifier);
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.chatDeleteSession,
      content: l10n.sessionsDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    operations.delete(widget.session.id);
    if (!widget.embedded) safePop<void>(context);
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

    final cs = theme.colorScheme;
    const gap = SizedBox(height: AppSpacing.xl);

    final sessionPending = ref.watch(
      sessionOperationsNotifierProvider.select<SessionOperationAction?>((ops) {
        final operation = ops[session.id];
        return operation != null && operation.isPending
            ? operation.request.action
            : null;
      }),
    );

    final podMachineId = meta?.machineId;
    final podOperationKeyForSession =
        session.isKubernetesSession &&
            podMachineId != null &&
            podMachineId.isNotEmpty
        ? podOperationKey(podMachineId, session.id)
        : null;
    final podOperation = podOperationKeyForSession == null
        ? null
        : ref.watch(
            podOperationsNotifierProvider.select<PodOperation?>(
              (ops) => ops[podOperationKeyForSession],
            ),
          );
    if (podOperationKeyForSession != null) {
      ref.listen<PodOperation?>(
        podOperationsNotifierProvider.select<PodOperation?>(
          (ops) => ops[podOperationKeyForSession],
        ),
        _onPodOperation,
      );
    }

    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        SessionInfoHeader(
          name: sessionName,
          subtitle: sessionSubtitle,
          flavor: meta?.flavor,
          badges: [
            StatusChip(isActive: session.isOnline),
            if (meta != null) SessionSandboxBadge(metadata: meta),
          ],
        ),

        // CLI Version Outdated Warning
        if (isCliOutdated) ...[
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            tone: AppBadgeTone.warning,
            title: l10n.sessionInfoCliOutdated,
            message: l10n.sessionInfoCliUpdateRun(
              'npm install -g happy-coder@latest',
            ),
            trailing: const Icon(Icons.copy_outlined),
            onTap: () => _copyToClipboard(
              'npm install -g happy-coder@latest',
              message: l10n.sessionInfoUpdateCommandCopied,
            ),
          ),
        ],

        if (session.isKubernetesSession) ...[
          gap,
          SessionPodSection(
            session: session,
            pod: _pod,
            logs: _podLogs,
            loading: _podLoading,
            actionRunning: podOperation?.isPending ?? false,
            error: _podError,
            failedOperation: podOperation?.isFailed ?? false
                ? podOperation
                : null,
            onRetryOperation: () => ref
                .read(podOperationsNotifierProvider.notifier)
                .retry(podOperationKeyForSession!),
            onDismissOperation: () => ref
                .read(podOperationsNotifierProvider.notifier)
                .dismiss(podOperationKeyForSession!),
            onRefresh: () => _refreshPod(loadLogs: _podLogs != null),
            onLoadLogs: () => _refreshPod(loadLogs: true),
            onHideLogs: () => setState(() => _podLogs = null),
            onPause: () => _runPodAction(KubernetesPodAction.pause),
            onResume: () => _runPodAction(KubernetesPodAction.resume),
            onKill: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: l10n.sessionPodKill,
                content: l10n.sessionPodKillConfirm,
                confirmLabel: l10n.sessionPodKill,
                isDestructive: true,
              );
              if (confirmed && mounted) {
                _runPodAction(KubernetesPodAction.kill);
              }
            },
          ),
        ],

        SessionNestingSections(session: session),

        gap,
        SettingsSection(
          title: l10n.sessionInfoSectionDetails,
          children: [
            InfoRow(
              icon: Icons.fingerprint,
              label: l10n.sessionInfoLabelSessionId,
              value: session.id,
              mono: true,
              onTap: () => _copyToClipboard(session.id),
            ),
            InfoRow(
              icon: Icons.access_time,
              label: l10n.sessionInfoLabelCreated,
              value: _formatDate(session.createdAt),
              inline: true,
            ),
            InfoRow(
              icon: Icons.update,
              label: l10n.sessionInfoLabelLastUpdated,
              value: _formatDate(session.updatedAt),
              inline: true,
            ),
            InfoRow(
              icon: Icons.tag,
              label: l10n.sessionInfoLabelSequence,
              value: session.seq.toString(),
              inline: true,
              mono: true,
            ),
          ],
        ),

        if (meta?.flavor != 'har' &&
            (meta?.machineId?.isNotEmpty ?? false)) ...[
          gap,
          SettingsSection(
            title: l10n.sessionStartupResumeSection,
            children: [
              SettingsToggleRow(
                icon: Icons.restart_alt_rounded,
                title: l10n.sessionStartupResumeTitle,
                subtitle: l10n.sessionStartupResumeDescription,
                value: _startupResumeEnabled,
                onChanged: (value) {
                  if (_startupResumeSaving) return;
                  setState(() => _startupResumeEnabled = value);
                },
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _startupResumeMessageController,
                      enabled: _startupResumeEnabled && !_startupResumeSaving,
                      decoration: InputDecoration(
                        labelText: l10n.sessionStartupResumeMessageLabel,
                        hintText: 'continue',
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.tonalIcon(
                        onPressed: _startupResumeSaving
                            ? null
                            : _saveStartupResume,
                        icon: _startupResumeSaving
                            ? const SizedBox.square(
                                dimension: AppIconSize.md,
                                child: AppCircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.commonSave),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        gap,
        SettingsSection(
          title: l10n.sessionInfoSectionQuickActions,
          children: [
            ActionRow(
              icon: Icons.bug_report_outlined,
              label: l10n.sessionInfoActionExportDebug,
              color: cs.primary,
              onTap: _exportDebugInfo,
            ),
            if (hasMachineAction)
              ActionRow(
                icon: Icons.dns_outlined,
                label: l10n.sessionInfoActionViewMachine,
                color: cs.primary,
                onTap: () => context.push('/machine/${meta!.machineId}'),
              ),
            if (hasArchiveAction)
              ActionRow(
                icon: Icons.archive_outlined,
                label: l10n.sessionInfoActionArchive,
                color: cs.error,
                isLoading: sessionPending == SessionOperationAction.archive,
                onTap: sessionPending != null ? null : _handleArchiveSession,
              ),
            if (hasDeleteAction)
              ActionRow(
                icon: Icons.delete_outline,
                label: l10n.sessionInfoActionDelete,
                color: cs.error,
                isLoading: sessionPending == SessionOperationAction.delete,
                onTap: sessionPending != null ? null : _handleDeleteSession,
              ),
          ],
        ),

        if (meta != null) ...[
          gap,
          SettingsSection(
            title: l10n.sessionInfoSectionMetadata,
            children: [
              InfoRow(
                icon: Icons.computer,
                label: l10n.sessionInfoLabelHost,
                value: meta.host,
              ),
              if (meta.path != null)
                InfoRow(
                  icon: Icons.folder_outlined,
                  label: l10n.sessionInfoLabelPath,
                  value: formatPathRelativeToHome(
                    meta.path!,
                    homeDir: meta.homeDir,
                  ),
                  mono: true,
                ),
              if (meta.machineId != null)
                InfoRow(
                  icon: Icons.dns_outlined,
                  label: l10n.sessionInfoLabelMachineId,
                  value: meta.machineId!,
                  mono: true,
                  onTap: () => _copyToClipboard(meta.machineId!),
                ),
              if (meta.os != null)
                InfoRow(
                  icon: Icons.memory,
                  label: l10n.sessionInfoLabelOs,
                  value: formatOSPlatform(meta.os),
                  inline: true,
                ),
              if (meta.version != null)
                InfoRow(
                  icon: isCliOutdated
                      ? Icons.warning_amber_outlined
                      : Icons.verified_outlined,
                  label: l10n.sessionInfoLabelCliVersion,
                  value: meta.version!,
                  inline: true,
                  mono: true,
                  iconColor: isCliOutdated
                      ? AppToneColors.of(
                          context,
                          AppBadgeTone.warning,
                        ).iconColor
                      : null,
                ),
              if (meta.flavor != null)
                InfoRow(
                  icon: Icons.auto_awesome,
                  label: l10n.sessionInfoLabelAiProvider,
                  value: _formatFlavor(meta.flavor, l10n),
                  inline: true,
                ),
              if (meta.claudeSessionId != null)
                InfoRow(
                  icon: Icons.code_outlined,
                  label: l10n.sessionInfoLabelClaudeSessionId,
                  value: meta.claudeSessionId!,
                  mono: true,
                  onTap: () => _copyToClipboard(meta.claudeSessionId!),
                ),
              if (meta.hostPid != null)
                InfoRow(
                  icon: Icons.terminal,
                  label: l10n.sessionInfoLabelProcessId,
                  value: meta.hostPid!.toString(),
                  inline: true,
                  mono: true,
                ),
              if (meta.happyHomeDir != null)
                InfoRow(
                  icon: Icons.home_outlined,
                  label: l10n.sessionInfoLabelHappyHome,
                  value: formatPathRelativeToHome(
                    meta.happyHomeDir!,
                    homeDir: meta.homeDir,
                  ),
                  mono: true,
                ),
              ActionRow(
                icon: Icons.copy_outlined,
                label: l10n.sessionInfoActionCopyMetadata,
                color: cs.primary,
                onTap: () {
                  _copyToClipboard(
                    jsonEncode(meta.toJson()),
                    message: l10n.sessionInfoMetadataCopied,
                  );
                },
              ),
            ],
          ),
        ],

        if (session.agentState != null) ...[
          gap,
          SettingsSection(
            title: l10n.sessionInfoSectionAgentState,
            children: [
              InfoRow(
                icon: Icons.person_outline,
                label: l10n.sessionInfoLabelControlledByUser,
                value: (session.agentState!.controlledByUser ?? false)
                    ? l10n.commonYes
                    : l10n.commonNo,
                inline: true,
              ),
              if (session.agentState!.requests != null &&
                  session.agentState!.requests!.isNotEmpty)
                InfoRow(
                  icon: Icons.hourglass_empty_outlined,
                  label: l10n.sessionInfoLabelPendingRequests,
                  value: session.agentState!.requests!.length.toString(),
                  inline: true,
                ),
            ],
          ),
        ],

        gap,
        SettingsSection(
          title: l10n.sessionInfoSectionActivity,
          children: [
            InfoRow(
              icon: Icons.lightbulb_outline,
              label: l10n.sessionInfoLabelThinking,
              value: session.thinking ? l10n.commonYes : l10n.commonNo,
              inline: true,
              iconColor: session.thinking ? cs.tertiary : null,
            ),
            if (session.thinking && session.thinkingAt != null)
              InfoRow(
                icon: Icons.timer_outlined,
                label: l10n.sessionInfoLabelThinkingSince,
                value: _formatDate(session.thinkingAt!),
                inline: true,
                iconColor: cs.tertiary,
              ),
          ],
        ),

        if (meta?.tools != null && meta!.tools!.isNotEmpty) ...[
          gap,
          SettingsSection(
            title: l10n.sessionInfoSectionTools,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tool in meta.tools!)
                      AppBadge(label: tool, outlined: true),
                  ],
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}
