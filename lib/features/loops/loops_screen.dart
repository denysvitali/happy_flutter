import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/loop.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'create_loop_sheet.dart';
import 'loop_card.dart';

/// Per-session list of scheduled prompts (loops).
///
/// Subscribes to the global [Sync.onLoopsChanged] stream and reflects
/// server-side state changes immediately. Mirrors the layout conventions
/// from `usage_screen.dart` — empty / loading / error states at the
/// top-level, with the populated list rendering underneath.
class LoopsScreen extends ConsumerStatefulWidget {
  const LoopsScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<LoopsScreen> createState() => _LoopsScreenState();
}

class _LoopsScreenState extends ConsumerState<LoopsScreen> {
  StreamSubscription<String>? _sub;
  bool _initialLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    _sub = sync.onLoopsChanged
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
    // Phase 1: hydrate from MMKV so cached loops paint immediately
    // (instead of a spinner that only clears once the server fetch
    // resolves or hits a timeout). This is what stops the "page loads
    // forever" symptom for users who already have cached state.
    final hasCached = ref.read(loopsNotifierProvider.notifier)
        .hydrateFromCache();
    if (mounted) {
      setState(() {
        _initialLoading = !hasCached;
        _error = null;
      });
    }
    if (hasCached) {
      // Phase 2: refresh in the background — we already have data to
      // show. unawaited() so the spinner stays hidden and the user
      // sees fresh data appear as it arrives via the onLoopsChanged
      // stream.
      unawaited(
        ref.read(loopsNotifierProvider.notifier).refreshFromSync(),
      );
      return;
    }
    try {
      await ref.read(loopsNotifierProvider.notifier).refreshFromSync();
    } catch (e, st) {
      logger.warning('LoopsScreen refresh failed: $e', e, st);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _initialLoading = false);
      }
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<Loop>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CreateLoopSheet(sessionId: widget.sessionId),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loopsLoopScheduled(created.id))),
      );
    }
  }

  Future<void> _deleteLoop(String loopId) async {
    try {
      await ref.read(loopsNotifierProvider.notifier).deleteLoop(
            sessionId: widget.sessionId,
            loopId: loopId,
          );
    } catch (e, st) {
      logger.warning('LoopsScreen delete failed: $e', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.loopsLoopCancelFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loops =
        ref.watch(loopsNotifierProvider.select(
      (state) => state[widget.sessionId] ?? const <Loop>[],
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loopsTitle),
      ),
      floatingActionButton: _initialLoading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.add),
              label: Text(l10n.loopsAddLoop),
            ),
      body: _initialLoading
          ? const AppLoadingIndicator()
          : _error != null
              ? _LoopsErrorState(
                  error: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    _refresh();
                  },
                )
              : loops.isEmpty
                  ? const _LoopsEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.xxxl * 2,
                        ),
                        itemCount: loops.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(
                          height: AppSpacing.md,
                        ),
                        itemBuilder: (context, idx) {
                          if (idx == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                l10n.loopsCount(loops.length),
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
                          final loop = loops[idx - 1];
                          return LoopCard(
                            key: ValueKey('loop-${loop.id}'),
                            loop: loop,
                            onPauseToggle: (paused) async {
                              await ref
                                  .read(loopsNotifierProvider.notifier)
                                  .pauseLoop(
                                    sessionId: widget.sessionId,
                                    loopId: loop.id,
                                    paused: paused,
                                  );
                            },
                            onDelete: () => _deleteLoop(loop.id),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _LoopsEmptyState extends StatelessWidget {
  const _LoopsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: Icons.schedule_outlined,
        title: l10n.loopsEmptyTitle,
        subtitle: l10n.loopsEmptyDescription,
      ),
    );
  }
}

class _LoopsErrorState extends StatelessWidget {
  const _LoopsErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: Icons.error_outline,
        title: l10n.loopsLoadFailed,
        subtitle: error,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.commonRetry),
        ),
      ),
    );
  }
}
