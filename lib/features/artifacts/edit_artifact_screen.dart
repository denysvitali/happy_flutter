import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for editing an existing artifact.
///
/// Loads the artifact from [artifactsNotifierProvider] using [artifactId].
/// Title and content fields are displayed for editing, but the actual
/// encryption and API update are out of scope — see TODO below.
class EditArtifactScreen extends ConsumerStatefulWidget {
  const EditArtifactScreen({
    required this.artifactId,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  final String artifactId;

  /// When true, this widget is rendered inside a master-detail pane and
  /// must not provide its own [Scaffold]/[AppBar].
  final bool embedded;

  /// Invoked after a successful save (or when the user cancels) when in
  /// embedded mode. Replaces the normal route pop.
  final VoidCallback? onClose;

  @override
  ConsumerState<EditArtifactScreen> createState() => _EditArtifactScreenState();
}

class _EditArtifactScreenState extends ConsumerState<EditArtifactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isBusy = false;
  bool _initialized = false;

  /// Whether the embedded editor is expanded to full-screen (tablet+).
  /// Only applies when [EditArtifactScreen.embedded] is true.
  bool _isFullscreen = false;

  void _initFromArtifact(DecryptedArtifact artifact) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = artifact.title ?? '';
    _contentController.text = artifact.body ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.artifactsEnterTitleOrContent)),
      );
      return;
    }

    final failedMsg = context.l10n.artifactsFailedToSave;
    setState(() => _isBusy = true);
    try {
      await sync.updateArtifact(
        widget.artifactId,
        title.isNotEmpty ? title : null,
        content.isNotEmpty ? content : null,
      );
      if (!mounted) return;
      if (widget.embedded) {
        widget.onClose?.call();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      logger.warning(
        '[EditArtifactScreen] updateArtifact failed: '
        'artifactId=${widget.artifactId} $e',
        e,
        st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failedMsg)));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final artifact = ref.watch(
      artifactsNotifierProvider.select(
        (artifacts) => artifacts[widget.artifactId],
      ),
    );

    if (artifact == null) {
      final emptyBody = AppEmptyState(
        icon: Icons.error_outline,
        title: l10n.errorNotFound,
      );
      if (widget.embedded) {
        return Column(
          children: [
            _EmbeddedEditHeader(
              title: l10n.artifactsEdit,
              isBusy: _isBusy,
              isFullscreen: _isFullscreen,
              onSave: _handleSave,
              onToggleFullscreen: () =>
                  setState(() => _isFullscreen = !_isFullscreen),
              onClose: widget.onClose,
            ),
            Expanded(child: emptyBody),
          ],
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(l10n.artifactsEdit)),
        body: emptyBody,
      );
    }

    // Populate fields once on first build after artifact loads.
    _initFromArtifact(artifact);

    final form = Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: AppScreenPadding.standard,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EncryptionNote(),
            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(label: l10n.artifactsTitleLabel),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: l10n.artifactsEnterTitle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLines: 1,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionLabel(label: l10n.artifactsContentLabel),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: l10n.artifactsEnterContent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                alignLabelWithHint: true,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 10,
              minLines: 6,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: AppLineHeight.normal,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              height: AppTouchTarget.comfortable,
              child: FilledButton(
                onPressed: _isBusy ? null : _handleSave,
                child: _isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        l10n.commonSave,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      final embeddedHeader = _EmbeddedEditHeader(
        title: l10n.artifactsEdit,
        isBusy: _isBusy,
        isFullscreen: _isFullscreen,
        onSave: _handleSave,
        onToggleFullscreen: () =>
            setState(() => _isFullscreen = !_isFullscreen),
        onClose: () {
          if (_isFullscreen) {
            // Exit full-screen first instead of closing.
            setState(() => _isFullscreen = false);
            return;
          }
          if (_titleController.text.trim() != (artifact.title ?? '') ||
              _contentController.text.trim() != (artifact.body ?? '')) {
            _showUnsavedChangesDialog(context, embedded: true);
            return;
          }
          widget.onClose?.call();
        },
      );

      final embeddedColumn = Column(
        children: [
          embeddedHeader,
          Expanded(child: form),
        ],
      );

      // In fullscreen mode use a Stack + Positioned.fill so the editor
      // overlays any surrounding pane/sidebar without needing a new route.
      if (_isFullscreen) {
        return Stack(
          children: [
            // Placeholder to keep parent layout stable.
            const SizedBox.shrink(),
            Positioned.fill(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 0,
                child: embeddedColumn,
              ),
            ),
          ],
        );
      }

      return embeddedColumn;
    }

    return PopScope(
      // Read current text at pop-gesture time, not build time,
      // to avoid stale state when text changes between canPop
      // evaluation and the callback being invoked.
      canPop: _titleController.text.trim() == (artifact.title ?? '') &&
          _contentController.text.trim() == (artifact.body ?? ''),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop &&
            (_titleController.text.trim() != (artifact.title ?? '') ||
                _contentController.text.trim() != (artifact.body ?? ''))) {
          _showUnsavedChangesDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.artifactsEdit),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton(
                onPressed: _isBusy ? null : _handleSave,
                child: _isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        l10n.commonSave,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: form,
      ),
    );
  }

  void _showUnsavedChangesDialog(
    BuildContext screenContext, {
    bool embedded = false,
  }) {
    final cs = Theme.of(screenContext).colorScheme;
    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.commonUnsavedChangesTitle),
          content: Text(l10n.commonUnsavedChangesContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.chatStay),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () {
                Navigator.pop(dialogContext);
                if (embedded) {
                  widget.onClose?.call();
                } else {
                  Navigator.of(screenContext).pop();
                }
              },
              child: Text(l10n.chatLeave),
            ),
          ],
        );
      },
    );
  }
}

/// Compact header for the embedded edit pane: title + save + fullscreen + close.
class _EmbeddedEditHeader extends StatelessWidget {
  const _EmbeddedEditHeader({
    required this.title,
    required this.isBusy,
    required this.isFullscreen,
    required this.onSave,
    required this.onToggleFullscreen,
    this.onClose,
  });

  final String title;
  final bool isBusy;

  /// Whether the editor is currently in full-screen mode.
  final bool isFullscreen;

  final Future<void> Function() onSave;

  /// Called when the user taps the fullscreen / fullscreen_exit button.
  final VoidCallback onToggleFullscreen;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: AppOpacity.half),
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: TextButton(
                    onPressed: isBusy ? null : onSave,
                    child: isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.commonSave,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                  ),
                  tooltip: isFullscreen
                      ? l10n.commonClose
                      : 'Expand to full screen',
                  onPressed: onToggleFullscreen,
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.commonClose,
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EncryptionNote extends StatelessWidget {
  const _EncryptionNote();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: cs.secondaryContainer.withValues(alpha: 0.4),
          width: AppBorder.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: cs.onSecondaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'The existing content is encrypted. '
              'Fields below will replace it once saved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w500,
                height: AppLineHeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        fontSize: AppFontSize.sm,
      ),
    );
  }
}
