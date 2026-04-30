import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import 'zen_priority.dart';

/// Screen for creating a new Zen todo item.
class ZenNewScreen extends ConsumerStatefulWidget {
  /// Creates the new Zen task screen.
  const ZenNewScreen({
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// When true, render without an outer Scaffold/AppBar so the screen
  /// can be embedded inside a master-detail pane.
  final bool embedded;

  /// Optional close handler invoked when the in-pane close button is
  /// tapped or after a successful save (embedded only).
  final VoidCallback? onClose;

  @override
  ConsumerState<ZenNewScreen> createState() => _ZenNewScreenState();
}

class _ZenNewScreenState extends ConsumerState<ZenNewScreen>
    with SyncSubscriptionMixin {
  final TextEditingController _contentController =
      TextEditingController();
  String _priority = 'medium';
  bool _isSaving = false;

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
    subscribeToDataChanged(ref, () {
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
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

  void _dismiss() {
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      context.pop();
    }
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

      ref
          .read(todoStateNotifierProvider.notifier)
          .addTodo(sessionId, item);

      if (!mounted) {
        return;
      }
      _dismiss();
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

    final submitButton = FilledButton(
      onPressed: canSubmit ? _addTask : null,
      child: _isSaving
          ? const SizedBox.square(
              dimension: AppSpacing.lg,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : Text(l10n.zenAddTask),
    );

    final formBody = Padding(
      padding: AppScreenPadding.standard,
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
          AppSectionHeader(
            title: l10n.zenPriorityLabel,
            padding: const EdgeInsets.only(
              bottom: AppSpacing.md,
            ),
          ),
          _PrioritySelector(
            priorities: _priorities,
            selected: _priority,
            colorScheme: cs,
            textTheme: theme.textTheme,
            onSelected: (value) =>
                setState(() => _priority = value),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.zenNewTask,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                submitButton,
                if (widget.onClose != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: AppBorder.thin,
            thickness: AppBorder.thin,
            color: theme.dividerColor,
          ),
          Expanded(child: formBody),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.zenNewTask),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(right: AppSpacing.sm),
            child: submitButton,
          ),
        ],
      ),
      body: formBody,
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
          color: colorScheme.onSurfaceVariant.withValues(
            alpha: AppOpacity.half + 0.1,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: AppBorder.thick,
          ),
        ),
        alignLabelWithHint: true,
        contentPadding:
            const EdgeInsets.all(AppSpacing.lg),
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
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: priorities.map((p) {
        final isSelected = p == selected;
        final color =
            ZenPriority.colorFor(p, colorScheme);
        return ChoiceChip(
          label: Text(p),
          selected: isSelected,
          selectedColor: color.withValues(
            alpha: AppOpacity.soft,
          ),
          labelStyle: textTheme.labelSmall?.copyWith(
            color: isSelected
                ? color
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: AppFontSize.sm,
          ),
          side: isSelected
              ? BorderSide(
                  color: color.withValues(
                    alpha: AppOpacity.half,
                  ),
                )
              : BorderSide(
                  color:
                      colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.pill),
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
