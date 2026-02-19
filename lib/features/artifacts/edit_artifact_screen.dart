import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title or content.'),
        ),
      );
      return;
    }

    // TODO(dev): Encrypt updated title and content using the artifact's
    // existing dataEncryptionKey, build an ArtifactUpdateRequest with
    // expectedHeaderVersion / expectedBodyVersion, submit via API client,
    // update the provider with the response, then navigate back.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TODO(dev): Artifact update with encryption not yet implemented.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artifacts = ref.watch(artifactsNotifierProvider);
    final artifact = artifacts[widget.artifactId];

    if (artifact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Artifact')),
        body: Center(
          child: Text(l10n.errorNotFound),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Artifact'),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EncryptionNote(),
              const SizedBox(height: 20),
              const _SectionLabel(label: 'TITLE'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter a new title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLines: 1,
              ),
              const SizedBox(height: 24),
              const _SectionLabel(label: 'CONTENT'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: 'Enter new content',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 10,
                minLines: 6,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _handleSave,
                child: Text(l10n.commonSave),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(76),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
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
