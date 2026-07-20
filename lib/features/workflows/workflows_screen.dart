import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/workflows_repository.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'workflow_card.dart';

/// Per-session list of Claude Code workflow runs.
class WorkflowsScreen extends ConsumerStatefulWidget {
  /// Creates a [WorkflowsScreen].
  const WorkflowsScreen({required this.sessionId, super.key});

  /// The session whose workflow runs are shown.
  final String sessionId;

  @override
  ConsumerState<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends ConsumerState<WorkflowsScreen> {
  StreamSubscription<String>? _sub;
  StreamSubscription<String>? _msgSub;
  Timer? _msgDebounce;
  bool _initialLoading = true;
  String? _error;
  bool _hasRetriedOnEmptyEvent = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    _sub = sync.onWorkflowsChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) {
          if (!mounted) return;
          setState(() {});
          if (_hasRetriedOnEmptyEvent) return;
          final runs = ref.read(
            workflowsNotifierProvider.select(
              (state) => state[widget.sessionId] ?? const <WorkflowRun>[],
            ),
          );
          if (runs.isEmpty && !_initialLoading) {
            _hasRetriedOnEmptyEvent = true;
            _refresh();
          }
        });
    // Rebuild live when this session's messages change (running foreground
    // workflows stream task_progress here), and debounce a refetch so a
    // background run that just wrote its on-disk snapshot flips to rich
    // promptly instead of staying a stale sparse row.
    _msgSub = sync.onSessionMessagesChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) {
          if (!mounted) return;
          setState(() {});
          _msgDebounce?.cancel();
          _msgDebounce = Timer(const Duration(seconds: 1), _refreshVisible);
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgSub?.cancel();
    _msgDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!sync.isInitialized) return;
    setState(() => _error = null);
    try {
      final notifier = ref.read(workflowsNotifierProvider.notifier);
      await notifier.refreshSession(widget.sessionId);
      // Also refresh other relevant sessions in the background so the
      // global workflows map stays up to date.
      unawaited(notifier.refreshFromSync());
    } catch (e, st) {
      logger.warning('WorkflowsScreen refresh failed: $e', e, st);
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  /// Refetch only the visible session's workflow list. Cheaper than
  /// [_refresh] (no global background sweep) so it is safe on a debounce.
  Future<void> _refreshVisible() async {
    if (!mounted || !sync.isInitialized) return;
    try {
      await ref
          .read(workflowsNotifierProvider.notifier)
          .refreshSession(widget.sessionId);
    } catch (e, st) {
      logger.warning('WorkflowsScreen visible refresh failed: $e', e, st);
    }
  }

  void _openRun(WorkflowRun run) {
    context.push(
      '/chat/${widget.sessionId}/workflow/${run.runId}',
      extra: run.toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(
      workflowsNotifierProvider.select(
        (state) => state[widget.sessionId] ?? const <WorkflowRun>[],
      ),
    );
    final isUnsupported = ref
        .read(workflowsRepositoryProvider)
        .isWorkflowListUnsupportedForSession(widget.sessionId);
    final messages = sync.messagesForSession(widget.sessionId);

    return Scaffold(
      appBar: AppBar(title: const Text('Workflows')),
      body: _initialLoading
          ? const AppLoadingIndicator()
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _refresh)
          : runs.isEmpty
          ? _EmptyState(isUnsupported: isUnsupported)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl * 2,
                ),
                itemCount: runs.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        '${runs.length} '
                        'workflow${runs.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final run = WorkflowRun.enrichFromMessages(
                    runs[index - 1],
                    messages,
                  );
                  return WorkflowCard(
                    key: ValueKey('workflow-${run.runId}'),
                    run: run,
                    onTap: () => _openRun(run),
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.isUnsupported = false});

  /// Whether the daemon reported that it does not support listing
  /// workflow runs (older CLI). Shown as a distinct message so the user
  /// knows workflows are unavailable rather than merely empty.
  final bool isUnsupported;

  @override
  Widget build(BuildContext context) {
    if (isUnsupported) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.update_disabled,
          title: 'Workflows unavailable',
          subtitle:
              'This machine is running a CLI version that does not '
              'support workflows. Update the Claude Code CLI to see them here.',
        ),
      );
    }
    return const Center(
      child: AppEmptyState(
        icon: Icons.account_tree_outlined,
        title: 'No workflows yet',
        subtitle: 'Workflow runs will appear here when Claude starts one.',
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.error_outline,
        title: 'Failed to load workflows',
        subtitle: error,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    );
  }
}
