import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  ConsumerState<EditArtifactScreen> createState() =>
      _EditArtifactScreenState();
}

class _EditArtifactScreenState
    extends ConsumerState<EditArtifactScreen> {
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
        SnackBar(
          content: Text(context.l10n.artifactsEnterTitleOrContent),
        ),
      );
      return;
    }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save artifact: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artifacts = ref.watch(artifactsNotifierProvider);
    final artifact = artifacts[widget.artifactId];

    if (artifact == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.artifactsEdit)),
        body: Center(
          child: Text(l10n.errorNotFound),
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
    final hasUnsavedChanges = currentTitle != originalTitle || currentContent != originalContent;

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvoked: (didPop) {
        if (!didPop && hasUnsavedChanges) {
          _showUnsavedChangesDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.artifactsEdit),
          actions: [
            TextButton(
              onPressed: _isBusy ? null : _handleSave,
              child: _isBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
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
                    ),
                    filled: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLines: 1,
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
                    ),
                    filled: true,
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 10,
                  minLines: 6,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                FilledButton(
                  onPressed: _isBusy ? null : _handleSave,
                  child: _isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.commonSave),
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
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(this.context).pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}

class _EncryptionNote extends StatelessWidget {
  const _EncryptionNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'The existing content is encrypted. '
              'Fields below will replace it once saved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSecondaryContainer,
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
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
    );
  }
}
