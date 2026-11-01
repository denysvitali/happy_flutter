part of 'chat_input.dart';

extension _ChatInputAttachmentActions on _ChatInputState {
  /// Picks one image from [source] and stages it on the controller.
  Future<void> _attachFrom(_AttachSource source) async {
    final controller = widget.attachmentController;
    if (controller == null || widget.isSending) return;
    final l10n = AppLocalizations.of(context);
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
                      key: ObjectKey(images[i]),
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

class _AttachmentThumb extends StatefulWidget {
  const _AttachmentThumb({
    required this.image,
    required this.onRemove,
    super.key,
  });

  final OutgoingImage image;
  final VoidCallback onRemove;

  @override
  State<_AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<_AttachmentThumb> {
  static const double _size = 56;

  // The composer rebuilds on every keystroke; decode the base64 payload once
  // per image instead of on each build.
  late Uint8List _bytes = base64Decode(widget.image.base64Data);

  @override
  void didUpdateWidget(_AttachmentThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image.base64Data, widget.image.base64Data)) {
      _bytes = base64Decode(widget.image.base64Data);
    }
  }

  /// Decodes at thumbnail resolution: the shorter side covers the box, so
  /// [BoxFit.cover] stays sharp without holding a full-size bitmap.
  ImageProvider _provider(BuildContext context) {
    final px = (_size * MediaQuery.devicePixelRatioOf(context)).ceil();
    final w = widget.image.width;
    final h = widget.image.height;
    final landscape = w != null && h != null && w > h;
    return ResizeImage(
      MemoryImage(_bytes),
      width: landscape ? null : px,
      height: landscape ? px : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onRemove = widget.onRemove;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image(
              image: _provider(context),
              width: _size,
              height: _size,
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
    final l10n = AppLocalizations.of(context);
    final label = isRecording
        ? l10n.chatStopDictation
        : isDownloadingModel
        ? (progressLabel ?? 'Downloading model')
        : isTranscribing
        ? 'Transcribing'
        : l10n.chatDictateMessage;

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
                      child: AppCircularProgressIndicator(
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
                      size: AppIconSize.xl,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
