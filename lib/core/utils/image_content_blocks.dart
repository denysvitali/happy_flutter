/// Helpers for Anthropic `image` content blocks carried in user message
/// `raw` payloads.
///
/// Two consumers:
/// - `MessageCacheService` strips inline base64 bytes before persisting
///   to MMKV so a chat with several screenshots cannot blow the offline
///   cache budget (200 messages × multi-MB strings).
/// - `Sync.retryFailedMessage` refuses to retry a message whose image
///   bytes were stripped, since sending the hollowed block would deliver
///   a broken image to the agent.
library;

/// Whether [raw] contains at least one image block whose base64 bytes
/// were stripped (empty `data` or explicit `omitted` marker).
bool hasStrippedImageBlocks(Map<String, dynamic> raw) {
  final content = raw['content'];
  if (content is! List) return false;
  for (final block in content) {
    if (block is! Map<String, dynamic>) continue;
    if (block['type'] != 'image') continue;
    final source = block['source'];
    if (source is! Map<String, dynamic>) continue;
    if (source['type'] != 'base64') continue;
    if (source['omitted'] == true) return true;
    final data = source['data'];
    if (data is! String || data.isEmpty) return true;
  }
  return false;
}

/// Returns a copy of [message] where every inline base64 image block in
/// `raw.content` has its `data` replaced by an empty string plus an
/// `omitted` marker.
///
/// Returns the original instance unchanged when the message carries no
/// inline image data, so cache writes for text-only lists stay cheap and
/// share structure with the live message list.
Map<String, dynamic> stripInlineImageData(Map<String, dynamic> message) {
  final raw = message['raw'];
  if (raw is! Map<String, dynamic>) return message;
  final content = raw['content'];
  if (content is! List) return message;

  var touched = false;
  final newContent = content.map((block) {
    if (block is! Map<String, dynamic>) return block;
    if (block['type'] != 'image') return block;
    final source = block['source'];
    if (source is! Map<String, dynamic>) return block;
    if (source['type'] != 'base64') return block;
    final data = source['data'];
    if (data is! String || data.isEmpty) return block;
    touched = true;
    return <String, dynamic>{
      ...block,
      'source': <String, dynamic>{
        ...source,
        'data': '',
        'omitted': true,
      },
    };
  }).toList();

  if (!touched) return message;
  return <String, dynamic>{
    ...message,
    'raw': <String, dynamic>{...raw, 'content': newContent},
  };
}
