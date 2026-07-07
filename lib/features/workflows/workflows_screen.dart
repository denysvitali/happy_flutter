import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
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
  bool _initialLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    _sub = sync.onWorkflowsChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!sync.isInitialized) return;
    setState(() => _error = null);
    try {
      await ref.read(workflowsNotifierProvider.notifier).refreshFromSync();
    } catch (e, st) {
      logger.warning('WorkflowsScreen refresh failed: $e', e, st);
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _initialLoading = false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflows'),
      ),
      body: _initialLoading
          ? const AppLoadingIndicator()
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _refresh)
              : runs.isEmpty
                  ? const _EmptyState()
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
                        separatorBuilder: (_, _) => const SizedBox(
                          height: AppSpacing.md,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                '${runs.length} '
                                'workflow${runs.length == 1 ? '' : 's'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            );
                          }
                          final run = runs[index - 1];
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
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
