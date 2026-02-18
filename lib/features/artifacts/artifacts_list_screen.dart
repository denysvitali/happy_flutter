import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';

/// Screen displaying the list of all artifacts.
class ArtifactsListScreen extends ConsumerWidget {
  const ArtifactsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final artifacts = ref.watch(artifactsNotifierProvider);
    final sortedArtifacts = artifacts.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Artifacts')),
      body: sortedArtifacts.isEmpty
          ? _buildEmptyState(context, l10n)
          : _buildList(context, sortedArtifacts),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/artifacts/new'),
        tooltip: l10n.commonCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Artifacts',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first artifact using the + button.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Artifact> artifacts,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: artifacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final artifact = artifacts[index];
        return _ArtifactListTile(artifact: artifact);
      },
    );
  }
}

class _ArtifactListTile extends StatelessWidget {
  const _ArtifactListTile({required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final shortId = artifact.id.length > 12
        ? '${artifact.id.substring(0, 12)}...'
        : artifact.id;
    final date = DateTime.fromMillisecondsSinceEpoch(
      artifact.createdAt,
    );
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';

    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(
        '[Encrypted] $shortId',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(dateStr),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/artifacts/${artifact.id}'),
    );
  }
}
