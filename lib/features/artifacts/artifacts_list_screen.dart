import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

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
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  int _lastDataChangeCounter = -1;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(artifactsNotifierProvider.notifier)
          .refreshFromSync();
      if (mounted) setState(() => _isLoading = false);
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      final counter = sync.dataChangeCounter;
      if (counter == _lastDataChangeCounter) return;
      _lastDataChangeCounter = counter;
      ref
          .read(artifactsNotifierProvider.notifier)
          .loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await ref
        .read(artifactsNotifierProvider.notifier)
        .refreshFromSync();
  }

  List<DecryptedArtifact> _filterAndSort(
    Map<String, DecryptedArtifact> artifacts,
  ) {
    var list = artifacts.values.toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((a) {
        final title = (a.title ?? '').toLowerCase();
        final id = a.id.toLowerCase();
        return title.contains(query) || id.contains(query);
      }).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artifacts = ref.watch(artifactsNotifierProvider);
    final filtered = _filterAndSort(artifacts);
    final hasArtifacts = artifacts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.artifactsTitle)),
      body: _isLoading
          ? const _ArtifactsLoadingShimmer()
          : !hasArtifacts
              ? _buildEmptyState(l10n)
              : _buildBody(l10n, filtered, artifacts.length),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/artifacts/new'),
        tooltip: l10n.commonCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.description_outlined,
      title: l10n.artifactsEmpty,
      subtitle: l10n.artifactsEmptySubtitle,
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    List<DecryptedArtifact> filtered,
    int totalCount,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search bar.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (v) => setState(() {
              _searchQuery = v.trim();
            }),
            decoration: InputDecoration(
              hintText: l10n.artifactsSearchHint,
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      tooltip: l10n.commonClear,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding:
                  const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                borderSide: BorderSide(
                  color: cs.primary,
                  width: AppBorder.thin,
                ),
              ),
              isDense: true,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        // Count label.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _searchQuery.isNotEmpty
                  ? l10n.artifactsCount(filtered.length)
                  : l10n.artifactsCount(totalCount),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        // List or no-results.
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyState(
                  icon: Icons.search_off,
                  title: l10n.artifactsNoResults,
                  subtitle: l10n.artifactsNoResultsSubtitle,
                )
              : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      // Extra bottom padding for FAB.
                      AppSpacing.xxxl * 3,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final artifact = filtered[index];
                      return Padding(
                        key: ValueKey(artifact.id),
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.sm,
                        ),
                        child: _ArtifactListCard(
                          artifact: artifact,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Type indicator helpers ──────────────────────────────────────

/// Returns icon and color based on artifact properties.
({IconData icon, Color color}) _artifactTypeIndicator(
  DecryptedArtifact artifact,
  ColorScheme cs,
) {
  final isDraft = artifact.draft ?? false;
  final hasSessions =
      artifact.sessions != null && artifact.sessions!.isNotEmpty;

  if (isDraft) {
    return (icon: Icons.edit_note, color: cs.tertiary);
  }
  if (!artifact.isDecrypted) {
    return (icon: Icons.lock_outlined, color: cs.error);
  }
  if (hasSessions) {
    return (
      icon: Icons.chat_bubble_outline,
      color: AppColors.iosBlue,
    );
  }
  return (
    icon: Icons.description_outlined,
    color: cs.primary,
  );
}

// ── Card ────────────────────────────────────────────────────────

class _ArtifactListCard extends StatelessWidget {
  const _ArtifactListCard({required this.artifact});

  final DecryptedArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final indicator = _artifactTypeIndicator(artifact, cs);

    final title = (artifact.title?.isNotEmpty ?? false)
        ? artifact.title!
        : _shortId(artifact.id);

    final isDraft = artifact.draft ?? false;
    final hasSessions = artifact.sessions != null &&
        artifact.sessions!.isNotEmpty;
    final sessionCount = artifact.sessions?.length ?? 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: () =>
          context.push('/artifacts/${artifact.id}'),
      child: Row(
        children: [
          SettingsIconContainer(
            icon: indicator.icon,
            color: indicator.color,
          ),
          const SizedBox(width: AppSpacing.md),
          // Title + metadata column.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with badges.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: AppLineHeight.tight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isDraft) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _TypeBadge(
                        label: context.l10n.artifactsDraft,
                        color: cs.tertiary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xsm),
                // Metadata row: date + session count.
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _relativeDate(
                        context, artifact.updatedAt,
                      ),
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: AppLineHeight.tight,
                      ),
                    ),
                    if (hasSessions) ...[
                      const SizedBox(width: AppSpacing.md),
                      Icon(
                        Icons.link,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$sessionCount',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: AppLineHeight.tight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right,
            size: AppSpacing.xl,
            color: cs.onSurface.withValues(
              alpha: AppOpacity.medium,
            ),
          ),
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length > 12) return '${id.substring(0, 12)}...';
    return id;
  }

  /// Format timestamp as relative date string.
  static String _relativeDate(
    BuildContext context,
    int millis,
  ) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return l10n.artifactsJustNow;
    if (diff.inHours < 1) {
      return l10n.artifactsMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return l10n.artifactsHoursAgo(diff.inHours);
    }
    if (diff.inDays == 1) return l10n.artifactsYesterday;
    if (diff.inDays < 7) {
      return l10n.artifactsDaysAgo(diff.inDays);
    }

    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    if (date.year == now.year) return '$mo-$d';
    return '${date.year}-$mo-$d';
  }
}

/// Small colored pill badge for artifact type / status labels.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.soft),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: AppBorder.hairline,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: AppFontSize.xxs,
            ),
      ),
    );
  }
}

// ── Loading shimmer ─────────────────────────────────────────────

class _ArtifactsLoadingShimmer extends StatelessWidget {
  const _ArtifactsLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.surfaceContainerHighest;

    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(
                  AppRadius.lg,
                ),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: AppOpacity.medium,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        AppRadius.sm,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120 + (index * 20.0) % 60,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(
                              AppRadius.xs,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: AppSpacing.xsm,
                        ),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(
                              AppRadius.xs,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
