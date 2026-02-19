import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Path'),
        actions: [
          TextButton(
            onPressed:
                _controller.text.trim().isNotEmpty ? _confirm : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Path text input
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
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
          ),
          const SizedBox(height: 16),

          // Recent paths from sessions
          if (recentPaths.isNotEmpty) ...[
            _buildSectionTitle(context, 'Recent Paths'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < recentPaths.length; i++)
                    _PathTile(
                      path: recentPaths[i],
                      selected: _controller.text.trim() ==
                          recentPaths[i],
                      showDivider: i < recentPaths.length - 1,
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
            _buildSectionTitle(context, 'Suggested Paths'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < suggestedPaths.length; i++)
                    _PathTile(
                      path: suggestedPaths[i],
                      selected: _controller.text.trim() ==
                          suggestedPaths[i],
                      showDivider:
                          i < suggestedPaths.length - 1,
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

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _controller.text.trim().isNotEmpty
                ? _confirm
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _PathTile extends StatelessWidget {

  const _PathTile({
    required this.path,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });
  final String path;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    path,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
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
