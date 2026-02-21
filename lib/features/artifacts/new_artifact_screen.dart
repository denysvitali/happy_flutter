import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart'; // for context.l10n extension
import '../../core/theme/app_tokens.dart';

/// Screen for creating a new artifact.
///
/// Shows a form with title and content fields. Actual encryption
/// and API submission are out of scope for this screen — see TODO below.
class NewArtifactScreen extends ConsumerStatefulWidget {
  const NewArtifactScreen({super.key});

  @override
  ConsumerState<NewArtifactScreen> createState() =>
      _NewArtifactScreenState();
}

class _NewArtifactScreenState
    extends ConsumerState<NewArtifactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
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

    // TODO(dev): Encrypt title and content, generate a data encryption key,
    // build an ArtifactCreateRequest, and submit via the API client.
    // Once the artifact is created and added to the provider, navigate
    // to the new artifact's detail screen with context.go('/artifacts/<id>').
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TODO(dev): Artifact creation with encryption not yet implemented.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.artifactsNew),
        actions: [
          TextButton(
            onPressed: _handleCreate,
            child: Text(l10n.commonCreate),
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
                onPressed: _handleCreate,
                child: Text(l10n.commonCreate),
              ),
            ],
          ),
        ),
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
