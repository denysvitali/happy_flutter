import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';

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
    final canSubmit =
        _contentController.text.trim().isNotEmpty && !_isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.zenNewTask),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: canSubmit ? _addTask : null,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.zenAddTask),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.zenPriorityLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _priorities.map((p) {
                final selected = p == _priority;
                return ChoiceChip(
                  label: Text(p),
                  selected: selected,
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
