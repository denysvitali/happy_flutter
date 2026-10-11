import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/components.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'widgets/artifact_form_fields.dart';
import 'widgets/artifact_pane_header.dart';
import '../../core/utils/snack.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

/// Screen for editing an existing artifact.
///
/// Loads the artifact from [artifactsNotifierProvider] using [artifactId].
/// Keeps unsaved changes guarded until a save or explicit discard.
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
  EditArtifactScreenState createState() => EditArtifactScreenState();
}

class EditArtifactScreenState extends ConsumerState<EditArtifactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isBusy = false;
  bool _initialized = false;
  String _originalTitle = '';
  String _originalContent = '';
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _isDirty =>
      _titleController.text != _originalTitle ||
      _contentController.text != _originalContent;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onEdited);
    _contentController.addListener(_onEdited);
  }

  void _onEdited() {
    if (_initialized) setState(() => _allowPop = false);
  }

  /// Whether the embedded editor is expanded to full-screen (tablet+).
  /// Only applies when [EditArtifactScreen.embedded] is true.
  bool _isFullscreen = false;

  void _initFromArtifact(DecryptedArtifact artifact) {
    if (_initialized) return;
    _originalTitle = artifact.title ?? '';
    _originalContent = artifact.body ?? '';
    _titleController.text = _originalTitle;
    _contentController.text = _originalContent;
    _initialized = true;
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
      context.showSnack(context.l10n.artifactsEnterTitleOrContent);
      return;
    }

    final failedMsg = context.l10n.artifactsFailedToSave;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(artifactsNotifierProvider.notifier)
          .saveArtifact(
            widget.artifactId,
            title: title.isNotEmpty ? title : null,
            body: content.isNotEmpty ? content : null,
          );
      if (!mounted) return;
      await _leave();
    } catch (e, st) {
      logger.warning(
        '[EditArtifactScreen] updateArtifact failed: '
        'artifactId=${widget.artifactId} $e',
        e,
        st,
      );
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
    final artifact = ref.watch(
      artifactsNotifierProvider.select(
        (artifacts) => artifacts[widget.artifactId],
      ),
    );

    if (artifact == null && !_initialized) {
      final emptyBody = AppEmptyState(
        icon: Icons.error_outline,
        title: l10n.errorNotFound,
      );
      if (widget.embedded) {
        return Column(
          children: [
            ArtifactPaneHeader(
              title: l10n.artifactsEdit,
              actions: [
                ArtifactBusyTextButton(
                  label: l10n.commonSave,
                  isBusy: _isBusy,
                  onPressed: _handleSave,
                ),
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  tooltip: _isFullscreen
                      ? l10n.commonClose
                      : 'Expand to full screen',
                  onPressed: () =>
                      setState(() => _isFullscreen = !_isFullscreen),
                ),
              ],
              onClose: _handleClose,
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
    if (artifact != null) _initFromArtifact(artifact);

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
                onPressed: _isBusy ? null : _handleSave,
                child: _isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: AppCircularProgressIndicator(strokeWidth: 2.5),
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
      ),
    );

    if (widget.embedded) {
      final embeddedHeader = ArtifactPaneHeader(
        title: l10n.artifactsEdit,
        actions: [
          ArtifactBusyTextButton(
            label: l10n.commonSave,
            isBusy: _isBusy,
            onPressed: _handleSave,
          ),
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
            tooltip: _isFullscreen ? l10n.commonClose : 'Expand to full screen',
            onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
          ),
        ],
        onClose: () {
          if (_isFullscreen) {
            setState(() => _isFullscreen = false);
            return;
          }
          _handleClose();
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
        return _guardPop(
          Stack(
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
          ),
        );
      }

      return _guardPop(embeddedColumn);
    }

    return _guardPop(
      Scaffold(
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
                        child: AppCircularProgressIndicator(strokeWidth: 2),
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

  Widget _guardPop(Widget child) {
    return PopScope(
      canPop: _allowPop || (!_isBusy && !_isDirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: child,
    );
  }

  Future<void> _handleClose() async {
    if (await confirmDiscard() && mounted) await _leave();
  }

  Future<void> _leave() async {
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    setState(() => _allowPop = true);
    // Publish the approved exit to PopScope before issuing the route pop.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  /// The master-detail host must ask before replacing this editor.
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
              style: AppText.label(Theme.of(context), cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
