import 'dart:convert';

import 'package:happy_flutter/core/wire/wire_parsers.dart';

/// Normalized arguments for Claude Code's `SendMessage` tool.
///
/// Claude Code and provider adapters have used `message`/`recipient`,
/// `content`/`to`, and one or more function-call envelopes. Keep the raw
/// normalized map so views can preserve fields added by newer adapters.
class SendMessageArguments {
  const SendMessageArguments({
    required this.input,
    this.message,
    this.recipient,
  });

  /// The unwrapped input map, retaining fields beyond the known pair.
  final Map<String, dynamic> input;

  /// Message text, preferring `message` over the legacy `content` field.
  final String? message;

  /// Recipient, preferring `recipient` over the legacy `to` field.
  final String? recipient;

  /// Whether [name] identifies a SendMessage tool emitted by a provider.
  static bool isToolName(String? name) {
    if (name == null) return false;
    final normalized = name.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'sendmessage' ||
        normalized == 'send_message' ||
        normalized.endsWith('__sendmessage') ||
        normalized.endsWith('__send_message') ||
        normalized.endsWith('.sendmessage') ||
        normalized.endsWith('.send_message');
  }

  /// Decodes direct, JSON-string, and nested function-call arguments.
  factory SendMessageArguments.from(dynamic rawInput) {
    final input = WireParsers.toolInput({'input': rawInput});
    return SendMessageArguments(
      input: input,
      message: _firstText(input, const ['message', 'content']),
      recipient: _firstText(input, const ['recipient', 'to']),
    );
  }

  /// Decodes the input stored on a normalized tool row.
  factory SendMessageArguments.fromTool(Map<String, dynamic> tool) =>
      SendMessageArguments.from(tool['input']);

  /// A compact one-line summary suitable for a collapsed tool header.
  String? get subtitle {
    final target = recipient?.trim();
    final body = message?.trim();
    if (target != null &&
        target.isNotEmpty &&
        body != null &&
        body.isNotEmpty) {
      return '$target: ${_firstLine(body)}';
    }
    return target?.isNotEmpty == true ? target : body;
  }

  static String? _firstText(Map<String, dynamic> input, List<String> keys) {
    for (final key in keys) {
      final value = WireParsers.parseString(input[key]);
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static String _firstLine(String value) {
    final line = value.split('\n').first.trim();
    const maxLength = 80;
    return line.length > maxLength ? '${line.substring(0, maxLength)}…' : line;
  }
}

/// Returns a readable result/acknowledgement from a SendMessage response.
String? sendMessageResultText(dynamic result) {
  if (result == null) return null;
  if (result is String) return result.trim().isEmpty ? null : result;

  final directText = _sendMessageContentText(result);
  if (directText != null) return directText;

  final map = WireParsers.asMap(result);
  if (map == null) return result.toString();
  for (final key in const [
    'message',
    'content',
    'result',
    'output',
    'status',
  ]) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    final nestedText = _sendMessageContentText(value);
    if (nestedText != null) return nestedText;
  }
  return null;
}

String? _sendMessageContentText(dynamic value) {
  final decoded = value is String ? _decodeJson(value) : value;
  final map = WireParsers.asMap(decoded);
  if (map != null) {
    for (final key in const [
      'message',
      'content',
      'result',
      'output',
      'status',
    ]) {
      final nested = map[key];
      if (nested is String && nested.trim().isNotEmpty) return nested;
      final nestedText = _sendMessageContentText(nested);
      if (nestedText != null) return nestedText;
    }
  }

  final blocks = WireParsers.asList(decoded);
  if (blocks == null || blocks.isEmpty) return null;

  final texts = <String>[];
  for (final block in blocks) {
    final blockMap = WireParsers.asMap(block);
    final text = blockMap?['text'];
    if (text is String && text.trim().isNotEmpty) {
      final parsedText = _sendMessageContentText(text);
      texts.add(parsedText ?? text);
    }
  }
  return texts.isEmpty ? null : texts.join('\n');
}

dynamic _decodeJson(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  try {
    return jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
}
