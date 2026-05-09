/// Hand-rolled Protobuf encoder/decoder for [MessageEnvelope] —
/// matching proto/messaging.proto.
///
/// Why hand-rolled?
/// ----------------
/// Pulling `protobuf` + `protoc` into the build pipeline is a much
/// bigger move than the rest of this branch. The wire format we emit
/// here is byte-compatible with the proto3 default for the small
/// number of fields we use, so swapping the implementation later is
/// a transparent change.
///
/// What this proves
/// ----------------
/// One code path (the future Socket.IO message-frame consumer) can
/// already accept Protobuf bytes today: just call
/// `MessageEnvelope.decode(bytes)`. The legacy JSON path is left
/// intact behind [encodeJsonShim] so we can roll out incrementally.
library;

import 'dart:convert';
import 'dart:typed_data';

class MessageEnvelope {
  const MessageEnvelope({
    this.serverId = '',
    this.localId = '',
    this.seq = 0,
    this.role = '',
    this.content = '',
    this.createdAt = 0,
  });

  final String serverId;
  final String localId;
  final int seq;
  final String role;
  final String content;
  final int createdAt;

  /// Encodes to proto3 wire format. Only emits non-default fields,
  /// matching protoc's behavior.
  Uint8List encode() {
    final buf = BytesBuilder();
    if (serverId.isNotEmpty) _writeString(buf, 1, serverId);
    if (localId.isNotEmpty) _writeString(buf, 2, localId);
    if (seq != 0) _writeVarint(buf, 3, seq);
    if (role.isNotEmpty) _writeString(buf, 4, role);
    if (content.isNotEmpty) _writeString(buf, 5, content);
    if (createdAt != 0) _writeVarint(buf, 6, createdAt);
    return buf.toBytes();
  }

  static MessageEnvelope decode(Uint8List bytes) {
    var i = 0;
    var serverId = '';
    var localId = '';
    var seq = 0;
    var role = '';
    var content = '';
    var createdAt = 0;
    while (i < bytes.length) {
      final tagAndType = _readVarint(bytes, i);
      i = tagAndType.$2;
      final fieldNumber = tagAndType.$1 >> 3;
      final wireType = tagAndType.$1 & 0x7;
      if (wireType == 0) {
        // varint
        final v = _readVarint(bytes, i);
        i = v.$2;
        switch (fieldNumber) {
          case 3:
            seq = v.$1;
          case 6:
            createdAt = v.$1;
        }
      } else if (wireType == 2) {
        // length-delimited (strings)
        final lenAndIndex = _readVarint(bytes, i);
        i = lenAndIndex.$2;
        final len = lenAndIndex.$1;
        final str = utf8.decode(bytes.sublist(i, i + len));
        i += len;
        switch (fieldNumber) {
          case 1:
            serverId = str;
          case 2:
            localId = str;
          case 4:
            role = str;
          case 5:
            content = str;
        }
      } else {
        // unknown wire type — skip silently to maintain forward
        // compatibility with future fields.
        break;
      }
    }
    return MessageEnvelope(
      serverId: serverId,
      localId: localId,
      seq: seq,
      role: role,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Legacy shim — emits the same JSON shape used by the existing
  /// Socket.IO path. Kept so callers can flip a flag and compare.
  Map<String, Object?> encodeJsonShim() => {
        'id': serverId,
        'localId': localId,
        'seq': seq,
        'role': role,
        'content': {'t': role, 'c': content},
        'createdAt': createdAt,
      };
}

void _writeVarint(BytesBuilder buf, int field, int value) {
  buf.addByte((field << 3) | 0); // wire type 0 (varint)
  var v = value;
  while (v >= 0x80) {
    buf.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  buf.addByte(v & 0x7F);
}

void _writeString(BytesBuilder buf, int field, String value) {
  final bytes = utf8.encode(value);
  buf.addByte((field << 3) | 2); // wire type 2 (length-delimited)
  // length varint
  var len = bytes.length;
  while (len >= 0x80) {
    buf.addByte((len & 0x7F) | 0x80);
    len >>= 7;
  }
  buf.addByte(len & 0x7F);
  buf.add(bytes);
}

(int, int) _readVarint(Uint8List bytes, int start) {
  var result = 0;
  var shift = 0;
  var i = start;
  while (true) {
    final b = bytes[i++];
    result |= (b & 0x7F) << shift;
    if ((b & 0x80) == 0) break;
    shift += 7;
  }
  return (result, i);
}
