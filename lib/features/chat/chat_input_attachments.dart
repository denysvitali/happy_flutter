part of 'chat_input.dart';

extension _ChatInputAttachmentActions on _ChatInputState {
  Future<void> _onAttachTap() async {
    final controller = widget.attachmentController;
    // Ignore attach while a send is in flight so an image cannot be staged
    // onto the next message while the controller is being cleared.
    if (controller == null || widget.isSending) return;
    final l10n = AppLocalizations.of(context);

    final source = await showModalBottomSheet<_AttachSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetL10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(sheetL10n.chatAttachFromGallery),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(sheetL10n.chatAttachFromCamera),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final result = source == _AttachSource.camera
        ? await _attachmentService.pickFromCameraResult()
        : await _attachmentService.pickFromGalleryResult();
    // Re-check after the async picker gap in case a send started meanwhile.
    final image = result.image;
    if (!mounted || widget.isSending) return;
    if (image == null) {
      if (!result.cancelled) {
        context.showSnack(l10n.chatImageAddFailed);
      }
      return;
    }

    if (!controller.add(image) && mounted) {
      context.showSnack(
        l10n.chatAttachmentLimit(ChatAttachmentController.maxAttachments),
      );
    }
  }

  Widget _buildAttachmentStrip(BuildContext context) {
    final controller = widget.attachmentController!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final images = controller.images;
        if (images.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < images.length; i++)
                    _AttachmentThumb(
                      image: images[i],
                      onRemove: () => controller.remove(images[i]),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _AttachSource { gallery, camera }

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = AppLocalizations.of(context).chatAttachImage;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.square(
            dimension: AppTouchTarget.min,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: AppIconSize.xxl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.image, required this.onRemove});

  final OutgoingImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.memory(
              base64Decode(image.base64Data),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            top: -AppSpacing.xsm,
            right: -AppSpacing.xsm,
            child: Semantics(
              button: true,
              label: l10n.chatRemoveAttachment,
              child: InkResponse(
                onTap: onRemove,
                radius: AppIconSize.sm,
                child: Container(
                  width: AppSpacing.xl,
                  height: AppSpacing.xl,
                  decoration: BoxDecoration(
                    color: colorScheme.inverseSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: AppIconSize.sm,
                    color: colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DictationButton extends StatelessWidget {
  const _DictationButton({
    required this.isRecording,
    required this.isTranscribing,
    required this.isDownloadingModel,
    required this.onTap,
    this.downloadProgress,
  });

  final bool isRecording;
  final bool isTranscribing;
  final bool isDownloadingModel;
  final OfflineSttDownloadProgress? downloadProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isRecording
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final busy = isTranscribing || isDownloadingModel;
    final progressLabel = downloadProgress?.label;
    final label = isRecording
        ? 'Stop dictation'
        : isDownloadingModel
        ? (progressLabel ?? 'Downloading model')
        : isTranscribing
        ? 'Transcribing'
        : 'Start dictation';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: busy ? null : onTap,
          radius: AppTouchTarget.min / 2,
          child: SizedBox.square(
            dimension: AppTouchTarget.min,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: AppIconSize.lg,
                      child: CircularProgressIndicator(
                        strokeWidth: AppBorder.thick,
                        color: colorScheme.primary,
                        value: isDownloadingModel
                            ? downloadProgress?.fraction
                            : null,
                      ),
                    )
                  : Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: color,
                      size: AppIconSize.xxl,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
