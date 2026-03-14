import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart'
    show AppSpacing, AppRadius;
import 'zen_priority.dart';

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
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TaskContentField(
              controller: _contentController,
              hintText: l10n.zenDescriptionHint,
              colorScheme: cs,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              l10n.zenPriorityLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PrioritySelector(
              priorities: _priorities,
              selected: _priority,
              colorScheme: cs,
              textTheme: theme.textTheme,
              onSelected: (value) => setState(() => _priority = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskContentField extends StatelessWidget {
  const _TaskContentField({
    required this.controller,
    required this.hintText,
    required this.colorScheme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ColorScheme colorScheme;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      maxLines: 5,
      minLines: 3,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({
    required this.priorities,
    required this.selected,
    required this.colorScheme,
    required this.textTheme,
    required this.onSelected,
  });

  final List<String> priorities;
  final String selected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: priorities.map((p) {
        final isSelected = p == selected;
        final color = ZenPriority.colorFor(p, colorScheme);
        return ChoiceChip(
          label: Text(p),
          selected: isSelected,
          selectedColor: color.withValues(alpha: 0.15),
          labelStyle: textTheme.labelSmall?.copyWith(
            color: isSelected ? color : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
          side: isSelected
              ? BorderSide(color: color.withValues(alpha: 0.5))
              : BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          onSelected: (_) => onSelected(p),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        );
      }).toList(growable: false),
    );
  }
}
