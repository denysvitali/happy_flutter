import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for editing an existing artifact.
///
/// Loads the artifact from [artifactsNotifierProvider] using [artifactId].
/// Title and content fields are displayed for editing, but the actual
/// encryption and API update are out of scope — see TODO below.
class EditArtifactScreen extends ConsumerStatefulWidget {
  const EditArtifactScreen({required this.artifactId, super.key});

  final String artifactId;

  @override
  ConsumerState<EditArtifactScreen> createState() => _EditArtifactScreenState();
}

class _EditArtifactScreenState extends ConsumerState<EditArtifactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isBusy = false;
  bool _initialized = false;

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
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
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
    final artifacts = ref.watch(artifactsNotifierProvider);
    final artifact = artifacts[widget.artifactId];

    if (artifact == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.artifactsEdit)),
        body: AppEmptyState(
          icon: Icons.error_outline,
          title: l10n.errorNotFound,
        ),
      );
    }

    // Populate fields once on first build after artifact loads.
    _initFromArtifact(artifact);

    // Check for unsaved changes
    final originalTitle = artifact.title ?? '';
    final originalContent = artifact.body ?? '';
    final currentTitle = _titleController.text.trim();
    final currentContent = _contentController.text.trim();
    final hasUnsavedChanges =
        currentTitle != originalTitle || currentContent != originalContent;

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasUnsavedChanges) {
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
        body: Form(
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
        ),
      ),
    );
  }

  void _showUnsavedChangesDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.commonUnsavedChangesTitle),
          content: Text(l10n.commonUnsavedChangesContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.chatStay),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(this.context).pop();
              },
              child: Text(l10n.chatLeave),
            ),
          ],
        );
      },
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
