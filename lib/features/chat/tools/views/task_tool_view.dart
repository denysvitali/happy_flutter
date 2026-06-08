import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import '../tool_section_view.dart';

/// Renders TaskCreate / TaskUpdate / TaskList / TaskGet tool calls.
///
/// All four share the same input envelope (subject, description, activeForm,
/// status) but differ in what they communicate to the user. The view
/// branches on [widget.tool]['name'] and renders the relevant subset. When
/// collapsed (`minimal: true`) the registry only shows the title + subject
/// in the header, so this body is only seen after a tap.
class TaskToolView extends StatelessWidget {
  const TaskToolView({required this.tool, super.key, this.metadata});

  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  String get _name => (tool['name'] as String?) ?? '';

  @override
  Widget build(BuildContext context) {
    final body = switch (_name) {
      'TaskCreate' => _buildCreate(context),
      'TaskUpdate' => _buildUpdate(context),
      'TaskList' => _buildList(context),
      'TaskGet' => _buildGet(context),
      _ => const SizedBox.shrink(),
    };
    return ToolSectionView(child: body);
  }

  Widget _buildCreate(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? const {};
    final subject = input['subject'] as String?;
    final description = input['description'] as String?;
    final activeForm = input['activeForm'] as String?;
    final status = input['status'] as String?;

    return _TaskBody(
      icon: Icons.add_task,
      iconColor: AppColors.success,
      headline: subject,
      sublines: [
        if (description != null && description.isNotEmpty) description,
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
      ],
      status: status,
    );
  }

  Widget _buildUpdate(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? const {};
    final taskId = input['taskId'] as String? ?? input['id'] as String?;
    final status = input['status'] as String?;
    final activeForm = input['activeForm'] as String?;
    final subject = input['subject'] as String?;

    return _TaskBody(
      icon: Icons.edit_note,
      iconColor: Theme.of(context).colorScheme.primary,
      headline: subject ?? (taskId != null ? 'Task #$taskId' : null),
      sublines: [
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
      ],
      status: status,
    );
  }

  Widget _buildList(BuildContext context) {
    final result = WireParsers.asMap(tool['result']);
    final items = _extractListItems(result);
    if (items.isEmpty) return const _EmptyHint('No tasks in list');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            '${items.length} task${items.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        for (final item in items) _ListRow(item: item),
      ],
    );
  }

  Widget _buildGet(BuildContext context) {
    final result = WireParsers.asMap(tool['result']);
    if (result == null) {
      final input = WireParsers.asMap(tool['input']) ?? const {};
      final id = input['taskId'] as String? ?? input['id'] as String?;
      return _EmptyHint(id != null ? 'No data for #$id' : 'No data');
    }
    final subject = (result['subject'] as String?) ??
        (result['title'] as String?) ??
        (result['description'] as String?);
    final status = result['status'] as String?;
    final activeForm = result['activeForm'] as String?;
    return _TaskBody(
      icon: Icons.task_alt,
      iconColor: Theme.of(context).colorScheme.primary,
      headline: subject,
      sublines: [
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
      ],
      status: status,
    );
  }

  static List<_TaskItem> _extractListItems(Map<String, dynamic>? result) {
    if (result == null) return const [];
    final raw = WireParsers.asList(result['tasks']) ??
        WireParsers.asList(result['items']) ??
        WireParsers.asList(result['todos']);
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _TaskItem(
              subject: m['subject'] as String? ??
                  m['title'] as String? ??
                  m['content'] as String? ??
                  m['description'] as String?,
              status: m['status'] as String?,
              activeForm: m['activeForm'] as String?,
            ))
        .where((t) => t.subject != null && t.subject!.isNotEmpty)
        .toList();
  }
}

class _TaskItem {
  const _TaskItem({this.subject, this.status, this.activeForm});
  final String? subject;
  final String? status;
  final String? activeForm;
}

/// Common layout for the single-task views (Create / Update / Get).
class _TaskBody extends StatelessWidget {
  const _TaskBody({
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.sublines,
    this.status,
  });

  final IconData icon;
  final Color iconColor;
  final String? headline;
  final List<String> sublines;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (headline != null && headline!.isNotEmpty)
                Text(
                  headline!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              for (final s in sublines)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxxs),
                  child: Text(
                    s,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: AppLineHeight.normal,
                    ),
                  ),
                ),
              if (status != null && status!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _StatusBadge(status: status!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.item});
  final _TaskItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.subject!, style: theme.textTheme.bodySmall),
                if (item.activeForm != null && item.activeForm!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.activeForm!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (item.status != null && item.status!.isNotEmpty)
            _StatusBadge(status: item.status!),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      'completed' => AppColors.success,
      'in_progress' => theme.colorScheme.primary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
    );
  }
}
