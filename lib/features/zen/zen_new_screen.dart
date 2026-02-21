import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for creating a new Zen todo item.
class ZenNewScreen extends ConsumerStatefulWidget {
  /// Creates the new Zen task screen.
  const ZenNewScreen({super.key});

  @override
  ConsumerState<ZenNewScreen> createState() => _ZenNewScreenState();
}

class _ZenNewScreenState extends ConsumerState<ZenNewScreen> {
  final TextEditingController _contentController = TextEditingController();
  String _priority = 'medium';
  bool _isSaving = false;
  StreamSubscription<void>? _syncSubscription;

  static const List<String> _priorities = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(todoStateNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _contentController.dispose();
    super.dispose();
  }

  String _resolveSessionId() {
    final sessions = ref.read(sessionsNotifierProvider);
    if (sessions.isNotEmpty) {
      return sessions.keys.first;
    }
    return 'global';
  }

  Future<void> _addTask() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final sessionId = _resolveSessionId();
      final now = DateTime.now().millisecondsSinceEpoch;
      final item = TodoItem(
        id: now.toString(),
        content: content,
        status: TodoState.pending,
        priority: _priority,
        order: 0,
        createdAt: now,
        updatedAt: now,
        sessionId: sessionId,
      );

      ref.read(todoStateNotifierProvider.notifier).addTodo(sessionId, item);

      if (!mounted) {
        return;
      }
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _priorityColor(String p, ColorScheme cs) {
    switch (p) {
      case 'critical':
        return cs.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return cs.tertiary;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canSubmit =
        _contentController.text.trim().isNotEmpty && !_isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.zenNewTask),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(
              onPressed: canSubmit ? _addTask : null,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: AppSpacing.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.zenAddTask),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l10n.zenDescriptionHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: cs.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: cs.primary,
                    width: 2,
                  ),
                ),
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.zenPriorityLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _priorities.map((p) {
                final selected = p == _priority;
                final color = _priorityColor(p, cs);
                return ChoiceChip(
                  label: Text(p),
                  selected: selected,
                  selectedColor: color.withValues(alpha: 0.18),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? color : cs.onSurfaceVariant,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                  side: selected
                      ? BorderSide(color: color.withValues(alpha: 0.6))
                      : BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  onSelected: (_) => setState(() => _priority = p),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
