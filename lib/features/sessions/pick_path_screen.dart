import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for entering or selecting a working directory path.
///
/// Optional [machineId] is used to look up the machine's home directory
/// and suggest recent paths used in sessions for that machine.
/// Pops with the entered path string when confirmed.
class PickPathScreen extends ConsumerStatefulWidget {

  const PickPathScreen({super.key, this.machineId});
  final String? machineId;

  @override
  ConsumerState<PickPathScreen> createState() => _PickPathScreenState();
}

class _PickPathScreenState extends ConsumerState<PickPathScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    context.pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = ref.watch(machinesNotifierProvider);
    final sessions = ref.watch(sessionsNotifierProvider);

    final machine = widget.machineId != null
        ? machines[widget.machineId]
        : null;
    final homeDir = machine?.metadata?.homeDir;

    // Compute recent paths for this machine from sessions
    final recentPaths = <String>[];
    if (widget.machineId != null) {
      final seen = <String>{};
      final sorted = sessions.values.toList()
        ..sort((a, b) =>
            (b.updatedAt).compareTo(a.updatedAt));
      for (final session in sorted) {
        if (session.metadata?.machineId == widget.machineId) {
          final p = session.metadata?.path;
          if (p != null && p.isNotEmpty && !seen.contains(p)) {
            seen.add(p);
            recentPaths.add(p);
          }
        }
      }
    }

    // Suggested paths when no recent history
    final suggestedPaths = homeDir != null
        ? [
            homeDir,
            '$homeDir/projects',
            '$homeDir/Documents',
            '$homeDir/Desktop',
          ]
        : <String>[];

    final hasText = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickSelectPath),
        actions: [
          TextButton(
            onPressed: hasText ? _confirm : null,
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Path text input
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'Enter path (e.g. /home/user/projects)',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Recent paths from sessions
          if (recentPaths.isNotEmpty) ...[
            const AppSectionHeader(title: 'Recent Paths'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < recentPaths.length; i++)
                    _PathTile(
                      path: recentPaths[i],
                      selected: _controller.text.trim() ==
                          recentPaths[i],
                      showDivider: i < recentPaths.length - 1,
                      isLast: i == recentPaths.length - 1,
                      onTap: () {
                        setState(() {
                          _controller.text = recentPaths[i];
                          _controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset:
                                  _controller.text.length,
                            ),
                          );
                        });
                      },
                    ),
                ],
              ),
            ),
          ],

          // Suggested paths when no recent history
          if (recentPaths.isEmpty &&
              suggestedPaths.isNotEmpty) ...[
            const AppSectionHeader(title: 'Suggested Paths'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < suggestedPaths.length; i++)
                    _PathTile(
                      path: suggestedPaths[i],
                      selected: _controller.text.trim() ==
                          suggestedPaths[i],
                      showDivider:
                          i < suggestedPaths.length - 1,
                      isLast: i == suggestedPaths.length - 1,
                      onTap: () {
                        setState(() {
                          _controller.text =
                              suggestedPaths[i];
                          _controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset:
                                  _controller.text.length,
                            ),
                          );
                        });
                      },
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: hasText ? _confirm : null,
              child: Text(l10n.commonConfirm),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathTile extends StatelessWidget {

  const _PathTile({
    required this.path,
    required this.selected,
    required this.showDivider,
    required this.isLast,
    required this.onTap,
  });
  final String path;
  final bool selected;
  final bool showDivider;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Round only the corners that are at the card edge.
    final borderRadius = BorderRadius.vertical(
      top: Radius.zero,
      bottom: isLast
          ? const Radius.circular(AppRadius.lg)
          : Radius.zero,
    );

    return Column(
      children: [
        AppTappable(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            color: selected
                ? theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.3)
                : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    path,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: selected
                          ? theme.colorScheme.onSurface
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 46,
            color: theme.colorScheme.outlineVariant,
          ),
      ],
    );
  }
}
