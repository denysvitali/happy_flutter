import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';

/// Screen displaying the list of all artifacts.
class ArtifactsListScreen extends ConsumerStatefulWidget {
  const ArtifactsListScreen({super.key});

  @override
  ConsumerState<ArtifactsListScreen> createState() =>
      _ArtifactsListScreenState();
}

class _ArtifactsListScreenState
    extends ConsumerState<ArtifactsListScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(artifactsNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(artifactsNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    List<DecryptedArtifact> artifacts,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: artifacts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final artifact = artifacts[index];
        return _ArtifactListTile(artifact: artifact);
      },
    );
  }
}

class _ArtifactListTile extends StatelessWidget {
  const _ArtifactListTile({required this.artifact});

  final DecryptedArtifact artifact;

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
