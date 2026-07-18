/// An image the user attached in the composer, ready to be embedded into
/// the outbound user message as an Anthropic `image` content block.
///
/// The daemon forwards user content-block arrays verbatim into Claude's
/// stream-json stdin, and Claude Code accepts base64 image blocks there
/// (verified end-to-end against claude 2.1.204 — URL-source blocks are
/// rejected by the API gateway with `400 unsupported image url`, which is
/// why attachments are always inlined as base64, never linked).
class OutgoingImage {
  const OutgoingImage({
    required this.mediaType,
    required this.base64Data,
    this.width,
    this.height,
  });

  /// `image/jpeg` or `image/png` — the only types the API accepts that
  /// [ImageAttachmentService] can always transcode into.
  final String mediaType;

  /// Base64-encoded image bytes (already downscaled to fit the API's
  /// per-image limits by the attachment service).
  final String base64Data;

  /// Pixel dimensions after downscaling, when known. Used only for
  /// preview aspect ratio in the composer; never sent to the server.
  final int? width;
  final int? height;

  /// Anthropic Messages API image block.
  Map<String, dynamic> toContentBlock() => <String, dynamic>{
    'type': 'image',
    'source': <String, dynamic>{
      'type': 'base64',
      'media_type': mediaType,
      'data': base64Data,
    },
  };
}
