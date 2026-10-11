import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'widgets/artifact_form_fields.dart';
import 'widgets/artifact_pane_header.dart';
import '../../core/utils/snack.dart';

/// Screen for creating a new artifact.
///
/// Keeps unsaved input guarded until creation or explicit discard.
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
  NewArtifactScreenState createState() => NewArtifactScreenState();
}

class NewArtifactScreenState extends ConsumerState<NewArtifactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isBusy = false;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _isDirty =>
      _titleController.text.isNotEmpty || _contentController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onEdited);
    _contentController.addListener(_onEdited);
  }

  void _onEdited() => setState(() => _allowPop = false);

  /// The master-detail host must ask before replacing this form.
  Future<bool> confirmDiscard() async {
    if (_isBusy || _confirmingDiscard) return false;
    if (!_isDirty) return true;
    _confirmingDiscard = true;
    try {
      final l10n = context.l10n;
      return await showConfirmDialog(
        context,
        title: l10n.commonUnsavedChangesTitle,
        content: l10n.commonUnsavedChangesContent,
        cancelLabel: l10n.chatStay,
        confirmLabel: l10n.chatLeave,
        isDestructive: true,
      );
    } finally {
      _confirmingDiscard = false;
    }
  }

  Future<void> _handleClose() async {
    if (!await confirmDiscard() || !mounted) return;
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Widget _guardPop(Widget child) => PopScope(
    canPop: _allowPop || (!_isBusy && !_isDirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handleClose();
    },
    child: child,
  );

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
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
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
              enabled: !_isBusy,
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
              enabled: !_isBusy,
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
                        child: AppCircularProgressIndicator(strokeWidth: 2.5),
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
      return _guardPop(
        Column(
          children: [
            ArtifactPaneHeader(
              title: l10n.artifactsNew,
              onClose: _handleClose,
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
        ),
      );
    }

    return _guardPop(
      Scaffold(
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
                        child: AppCircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}
