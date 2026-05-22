import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/components/tablet/master_detail_scaffold.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import 'artifact_detail_screen.dart';
import 'edit_artifact_screen.dart';
import 'new_artifact_screen.dart';

/// Inline detail mode rendered in the side pane on wide layouts.
enum _InlineMode { none, view, edit, create }

/// Screen displaying the list of all artifacts.
class ArtifactsListScreen extends ConsumerStatefulWidget {
  const ArtifactsListScreen({super.key});

  @override
  ConsumerState<ArtifactsListScreen> createState() =>
      _ArtifactsListScreenState();
}

class _ArtifactsListScreenState extends ConsumerState<ArtifactsListScreen>
    with SyncSubscriptionMixin {
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  String? _selectedArtifactId;
  _InlineMode _inlineMode = _InlineMode.none;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(artifactsNotifierProvider.notifier).loadFromSync();
      await ref.read(artifactsNotifierProvider.notifier).refreshFromSync();
      if (mounted) setState(() => _isLoading = false);
    });
    subscribeToDomains([SyncDomain.artifacts], () {
      ref.read(artifactsNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await ref.read(artifactsNotifierProvider.notifier).refreshFromSync();
  }

  void _clearInline() {
    setState(() {
      _selectedArtifactId = null;
      _inlineMode = _InlineMode.none;
    });
  }

  void _selectInlineView(String id) {
    setState(() {
      _selectedArtifactId = id;
      _inlineMode = _InlineMode.view;
    });
  }

  void _selectInlineEdit() {
    if (_selectedArtifactId == null) return;
    setState(() => _inlineMode = _InlineMode.edit);
  }

  void _selectInlineCreate() {
    setState(() {
      _selectedArtifactId = null;
      _inlineMode = _InlineMode.create;
    });
  }

  /// Resolves which inline detail widget to render in the side pane.
  Widget _resolveInlineDetail() {
    switch (_inlineMode) {
      case _InlineMode.view:
        final id = _selectedArtifactId;
        if (id == null) {
          return const SizedBox.shrink();
        }
        return ArtifactDetailScreen(
          key: ValueKey('artifact-view-$id'),
          artifactId: id,
          embedded: true,
          onClose: _clearInline,
          onEdit: _selectInlineEdit,
        );
      case _InlineMode.edit:
        final id = _selectedArtifactId;
        if (id == null) {
          return const SizedBox.shrink();
        }
        return EditArtifactScreen(
          key: ValueKey('artifact-edit-$id'),
          artifactId: id,
          embedded: true,
          onClose: () {
            // After save / cancel transition back to view mode if we still
            // have a selection, otherwise clear the pane.
            if (_selectedArtifactId != null) {
              setState(() => _inlineMode = _InlineMode.view);
            } else {
              _clearInline();
            }
          },
        );
      case _InlineMode.create:
        return NewArtifactScreen(
          key: const ValueKey('artifact-create'),
          embedded: true,
          onClose: _clearInline,
          onCreated: (artifactId) {
            // Successful create transitions the pane to view mode for the
            // freshly created artifact.
            setState(() {
              _selectedArtifactId = artifactId;
              _inlineMode = _InlineMode.view;
            });
          },
        );
      case _InlineMode.none:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isWide = MasterDetailScaffold.isWide(context);
    final artifacts = ref.watch(artifactsNotifierProvider);
    final filtered = _filterAndSort(artifacts);
    final hasArtifacts = artifacts.isNotEmpty;

    if (!isWide) {
      // Phone layout: clear any inline selection so it doesn't reappear if
      // the device rotates back to wide later. Use a post-frame callback to
      // avoid mutating state during build.
      if (_selectedArtifactId != null || _inlineMode != _InlineMode.none) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_selectedArtifactId != null ||
              _inlineMode != _InlineMode.none) {
            _clearInline();
          }
        });
      }
    }

    final masterBody = _isLoading
        ? const _ArtifactsLoadingShimmer()
        : !hasArtifacts
        ? _buildEmptyState(l10n)
        : _buildBody(
            l10n,
            filtered,
            artifacts.length,
            onTap: isWide
                ? _selectInlineView
                : (id) => context.push('/artifacts/$id'),
            selectedId: isWide ? _selectedArtifactId : null,
          );

    final hasSelection = _selectedArtifactId != null ||
        _inlineMode == _InlineMode.create;

    final scaffoldBody = isWide
        ? MasterDetailScaffold(
            master: masterBody,
            detail: _resolveInlineDetail(),
            hasSelection: hasSelection,
            emptyDetail: const TabletDetailEmpty(
              icon: Icons.description_outlined,
              // TODO(i18n): localize side-pane empty placeholder.
              message: 'Select an artifact',
            ),
          )
        : masterBody;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.artifactsTitle)),
      body: scaffoldBody,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isWide) {
            _selectInlineCreate();
          } else {
            context.push('/artifacts/new');
          }
        },
        tooltip: l10n.commonCreate,
        child: const Icon(Icons.add),
      ),
    );
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
    int totalCount, {
    required ValueChanged<String> onTap,
    String? selectedId,
  }) {
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
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
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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
                    physics: const AlwaysScrollableScrollPhysics(),
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
                      final isSelected = selectedId == artifact.id;
                      return Padding(
                        key: ValueKey(artifact.id),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ArtifactListCard(
                          artifact: artifact,
                          selected: isSelected,
                          onTap: () => onTap(artifact.id),
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
    return (icon: Icons.chat_bubble_outline, color: AppColors.iosBlue);
  }
  return (icon: Icons.description_outlined, color: cs.primary);
}

// ── Card ────────────────────────────────────────────────────────

class _ArtifactListCard extends StatelessWidget {
  const _ArtifactListCard({
    required this.artifact,
    this.selected = false,
    this.onTap,
  });

  final DecryptedArtifact artifact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final indicator = _artifactTypeIndicator(artifact, cs);

    final title = (artifact.title?.isNotEmpty ?? false)
        ? artifact.title!
        : _shortId(artifact.id);

    final isDraft = artifact.draft ?? false;
    final hasSessions =
        artifact.sessions != null && artifact.sessions!.isNotEmpty;
    final sessionCount = artifact.sessions?.length ?? 0;

    final card = AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: onTap ?? () => context.push('/artifacts/${artifact.id}'),
      child: Row(
        children: [
          SettingsIconContainer(icon: indicator.icon, color: indicator.color),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
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
                      _relativeDate(context, artifact.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: AppLineHeight.tight,
                      ),
                    ),
                    if (hasSessions) ...[
                      const SizedBox(width: AppSpacing.md),
                      Icon(Icons.link, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$sessionCount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: AppLineHeight.tight,
                        ),
                      ),
                    ],
                  ],
                ),
                if (artifact.body != null &&
                    artifact.body!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xsm),
                  // Content preview snippet.
                  Text(
                    artifact.body!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: AppLineHeight.tight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right,
            size: AppSpacing.xl,
            color: cs.onSurface.withValues(alpha: AppOpacity.medium),
          ),
        ],
      ),
    );

    if (!selected) return card;

    // Highlight the currently selected row in the master pane.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppOpacity.medium),
          width: AppBorder.thin,
        ),
      ),
      child: card,
    );
  }

  String _shortId(String id) {
    if (id.length > 12) return '${id.substring(0, 12)}...';
    return id;
  }

  /// Format timestamp as relative date string.
  static String _relativeDate(BuildContext context, int millis) {
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
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: AppOpacity.medium),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120 + (index * 20.0) % 60,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xsm),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
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
