import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
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
  ConsumerState<PickPathScreen> createState() =>
      _PickPathScreenState();
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
        ..sort(
          (a, b) => b.updatedAt.compareTo(a.updatedAt),
        );
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
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: hasText ? _confirm : null,
              child: Text(
                l10n.commonConfirm,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasText
                      ? cs.primary
                      : cs.onSurface.withValues(
                          alpha: AppOpacity.medium,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppScreenPadding.standard,
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // ── Path text input ───────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: l10n.pickPathHint,
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.folder_outlined,
                  color: hasText
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                suffixIcon: hasText
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        iconSize: 18,
                        color: cs.onSurfaceVariant,
                        onPressed: () =>
                            setState(() => _controller.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Recent paths ──────────────────────────────────────────
          if (recentPaths.isNotEmpty) ...[
            AppSectionHeader(title: l10n.pickRecentPaths),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < recentPaths.length; i++) ...[
                    _PathTile(
                      path: recentPaths[i],
                      selected: _controller.text.trim() ==
                          recentPaths[i],
                      isFirst: i == 0,
                      isLast: i == recentPaths.length - 1,
                      onTap: () {
                        setState(() {
                          _controller.text = recentPaths[i];
                          _controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset: _controller.text.length,
                            ),
                          );
                        });
                      },
                    ),
                    if (i < recentPaths.length - 1)
                      Divider(
                        height: 1,
                        indent: AppSpacing.lg + 36 + AppSpacing.md,
                        color: cs.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Suggested paths ───────────────────────────────────────
          if (recentPaths.isEmpty &&
              suggestedPaths.isNotEmpty) ...[
            AppSectionHeader(title: l10n.pickSuggestedPaths),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0;
                      i < suggestedPaths.length;
                      i++) ...[
                    _PathTile(
                      path: suggestedPaths[i],
                      selected: _controller.text.trim() ==
                          suggestedPaths[i],
                      isFirst: i == 0,
                      isLast: i == suggestedPaths.length - 1,
                      onTap: () {
                        setState(() {
                          _controller.text = suggestedPaths[i];
                          _controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset: _controller.text.length,
                            ),
                          );
                        });
                      },
                    ),
                    if (i < suggestedPaths.length - 1)
                      Divider(
                        height: 1,
                        indent: AppSpacing.lg + 36 + AppSpacing.md,
                        color: cs.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Confirm button ────────────────────────────────────────
          SizedBox(
            height: AppTouchTarget.comfortable,
            child: FilledButton.icon(
              onPressed: hasText ? _confirm : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                l10n.commonConfirm,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  const _PathTile({
    required this.path,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String path;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Round only the corners that are at the card edge.
    final borderRadius = BorderRadius.vertical(
      top: isFirst
          ? const Radius.circular(AppRadius.lg)
          : Radius.zero,
      bottom: isLast
          ? const Radius.circular(AppRadius.lg)
          : Radius.zero,
    );

    return AppTappable(
      onTap: onTap,
      borderRadius: borderRadius,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        color: selected
            ? cs.primary.withValues(alpha: AppOpacity.faint)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            SettingsIconContainer(
              icon: selected
                  ? Icons.folder_rounded
                  : Icons.folder_outlined,
              color: selected
                  ? cs.primary
                  : cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                path,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: selected ? FontWeight.w600 : null,
                  color: selected ? cs.onSurface : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: cs.primary,
              ),
            ] else ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onSurface
                    .withValues(alpha: AppOpacity.medium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
