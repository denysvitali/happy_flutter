import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/artifact_form_fields.dart';
import 'widgets/artifact_pane_header.dart';
import '../../core/utils/snack.dart';

/// Screen for creating a new artifact.
///
/// Shows a form with title and content fields. Actual encryption
/// and API submission are out of scope for this screen — see TODO below.
class NewArtifactScreen extends ConsumerStatefulWidget {
  const NewArtifactScreen({
    this.embedded = false,
    this.onClose,
    this.onCreated,
    super.key,
  });

  /// When true, this widget is rendered inside a master-detail pane and
  /// must not provide its own [Scaffold]/[AppBar].
  final bool embedded;

  /// Invoked when the user closes the create pane in embedded mode (without
  /// creating an artifact).
  final VoidCallback? onClose;

  /// Invoked with the freshly created artifact id in embedded mode. Replaces
  /// the normal `context.go('/artifacts/$id')` navigation so the master-detail
  /// host can transition to view mode for the new artifact.
  final void Function(String artifactId)? onCreated;

  @override
  ConsumerState<NewArtifactScreen> createState() => _NewArtifactScreenState();
}

class _NewArtifactScreenState extends ConsumerState<NewArtifactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isBusy = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      context.showSnack(context.l10n.artifactsEnterTitleOrContent);
      return;
    }

    final failedMsg = context.l10n.artifactsFailedToCreate;
    setState(() => _isBusy = true);
    try {
      final artifactId = await ref
          .read(artifactsNotifierProvider.notifier)
          .createArtifact(
            title.isNotEmpty ? title : null,
            content.isNotEmpty ? content : null,
          );
      if (!mounted) return;
      if (widget.embedded) {
        widget.onCreated?.call(artifactId);
      } else {
        context.go('/artifacts/$artifactId');
      }
    } catch (e, st) {
      logger.warning('[NewArtifactScreen] createArtifact failed: $e', e, st);
      if (!mounted) return;
      context.showSnack(failedMsg);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final form = Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: AppScreenPadding.standard,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArtifactSectionLabel(label: l10n.artifactsTitleLabel),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _titleController,
              decoration: artifactFieldDecoration(
                context,
                hintText: l10n.artifactsEnterTitle,
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLines: 1,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ArtifactSectionLabel(label: l10n.artifactsContentLabel),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _contentController,
              decoration: artifactFieldDecoration(
                context,
                hintText: l10n.artifactsEnterContent,
                alignLabelWithHint: true,
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
                onPressed: _isBusy ? null : _handleCreate,
                child: _isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        l10n.commonCreate,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          ArtifactPaneHeader(
            title: l10n.artifactsNew,
            onClose: widget.onClose,
            actions: [
              ArtifactBusyTextButton(
                label: l10n.commonCreate,
                isBusy: _isBusy,
                onPressed: _handleCreate,
              ),
            ],
          ),
          Expanded(child: form),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.artifactsNew),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: _isBusy ? null : _handleCreate,
              child: _isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      l10n.commonCreate,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: form,
    );
  }
}
