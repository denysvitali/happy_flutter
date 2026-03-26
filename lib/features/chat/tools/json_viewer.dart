import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_tokens.dart';

// ---------------------------------------------------------------------------
// Syntax-highlight color palettes
// ---------------------------------------------------------------------------

class _JsonColors {
  const _JsonColors({
    required this.key,
    required this.string,
    required this.number,
    required this.boolean,
    required this.nullValue,
    required this.bracket,
    required this.punctuation,
    required this.muted,
  });

  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nullValue;
  final Color bracket;
  final Color punctuation;
  final Color muted;

  static _JsonColors of(Brightness brightness, Color onSurface) {
    if (brightness == Brightness.dark) {
      return _JsonColors(
        key: const Color(0xFF9CDCFE),
        string: const Color(0xFFCE9178),
        number: const Color(0xFFB5CEA8),
        boolean: const Color(0xFF569CD6),
        nullValue: const Color(0xFF569CD6),
        bracket: const Color(0xFFFFD700),
        punctuation: onSurface.withValues(alpha: 0.5),
        muted: onSurface.withValues(alpha: 0.4),
      );
    }
    return _JsonColors(
      key: const Color(0xFF0451A5),
      string: const Color(0xFFA31515),
      number: const Color(0xFF098658),
      boolean: const Color(0xFF0000FF),
      nullValue: const Color(0xFF0000FF),
      bracket: const Color(0xFF795E26),
      punctuation: onSurface.withValues(alpha: 0.5),
      muted: onSurface.withValues(alpha: 0.4),
    );
  }
}

TextStyle _mono(BuildContext context) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Courier New', 'Courier'],
    fontSize: AppFontSize.sm,
    height: AppLineHeight.relaxed,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Scrollable container that auto-detects JSON content and renders it with
/// [JsonTreeViewer] (syntax highlighting + expand/collapse).  Falls back to
/// plain monospace text when the content is not valid JSON.
///
/// [content] may be a [String] (JSON or plain text), a [Map], or a [List].
class SmartOutputContainer extends StatefulWidget {
  const SmartOutputContainer({required this.content, super.key});

  final dynamic content;

  @override
  State<SmartOutputContainer> createState() =>
      _SmartOutputContainerState();
}

class _SmartOutputContainerState extends State<SmartOutputContainer> {
  late final (bool, dynamic, String?) _parsed =
      _tryParseJson(widget.content);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (isJson, jsonValue, plainText) = _parsed;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: SingleChildScrollView(
        child: isJson
            ? JsonTreeViewer(value: jsonValue)
            : SelectableText(
                plainText ??
                    (widget.content is String
                        ? widget.content as String
                        : widget.content.toString()),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Courier New', 'Courier'],
                  fontSize: AppFontSize.sm,
                  color: theme.colorScheme.onSurface,
                  height: AppLineHeight.relaxed,
                ),
              ),
      ),
    );
  }

  /// Parses [value] into displayable form.
  ///
  /// Returns `(isJson, jsonValue, plainText)`:
  /// - `isJson` true  → render [jsonValue] with [JsonTreeViewer]
  /// - `isJson` false → render [plainText] (or fall back to
  ///   `widget.content`)
  ///
  /// Handles MCP content blocks at both the Dart-object level
  /// (already-parsed List) AND the String level (JSON-encoded
  /// wrapper that was not pre-parsed).
  static (bool, dynamic, String?) _tryParseJson(dynamic value) {
    final unwrapped = _unwrapMcpContentBlocks(value);
    if (unwrapped is Map || unwrapped is List) {
      return (true, unwrapped, null);
    }
    if (unwrapped is String) {
      final trimmed = unwrapped.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(unwrapped);
          // The decoded value might itself be an MCP content-block
          // wrapper (e.g. the content arrived as a JSON string
          // rather than a pre-parsed List).
          final inner = _unwrapMcpContentBlocks(decoded);
          if (inner is String) {
            final innerTrimmed = inner.trim();
            if (innerTrimmed.startsWith('{') ||
                innerTrimmed.startsWith('[')) {
              try {
                return (true, jsonDecode(inner), null);
              } catch (_) {
                // Inner text is not JSON — show as plain text.
              }
            }
            return (false, null, inner);
          }
          if (inner is Map || inner is List) {
            return (true, inner, null);
          }
          return (true, decoded, null);
        } catch (e) {
          logger.info(
            'Failed to parse JSON in viewer: $e',
          );
        }
      }
      return (false, null, unwrapped);
    }
    return (false, null, null);
  }

  /// Unwraps MCP tool result content blocks.
  ///
  /// MCP tools return results as `[{"type": "text", "text": "..."}]`.
  /// When all items are text blocks, this extracts the text content
  /// (joining with newlines if multiple) so the inner value — which is
  /// often JSON — can be rendered properly instead of showing the raw
  /// wrapper structure.
  static dynamic _unwrapMcpContentBlocks(dynamic value) {
    if (value is! List || value.isEmpty) return value;
    final texts = <String>[];
    for (final item in value) {
      if (item is! Map) return value;
      if (item['type'] != 'text') return value;
      final text = item['text'];
      if (text is! String) return value;
      texts.add(text);
    }
    return texts.length == 1 ? texts.first : texts.join('\n');
  }
}

/// Renders a pre-parsed JSON value as a collapsible tree with syntax
/// highlighting.  Suitable for embedding in a [ScrollView].
class JsonTreeViewer extends StatelessWidget {
  const JsonTreeViewer({required this.value, super.key});

  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return _JsonNode(value: value, depth: 0, trailingComma: false);
  }
}

// ---------------------------------------------------------------------------
// Internal recursive node
// ---------------------------------------------------------------------------

class _JsonNode extends StatefulWidget {
  const _JsonNode({
    required this.value,
    required this.depth,
    required this.trailingComma,
  });

  final dynamic value;
  final int depth;
  final bool trailingComma;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Auto-collapse past depth 1 for large containers.
    final v = widget.value;
    if (v is Map) {
      _expanded = widget.depth < 2 || v.length <= 3;
    } else if (v is List) {
      _expanded = widget.depth < 2 || v.length <= 3;
    } else {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    if (v is Map) {
      final map = Map<String, dynamic>.from(v);
      return _buildObject(context, map);
    } else if (v is List) {
      return _buildArray(context, v);
    } else {
      return _buildPrimitive(context, v);
    }
  }

  // -------------------------------------------------------------------------
  // Object
  // -------------------------------------------------------------------------

  Widget _buildObject(BuildContext context, Map<String, dynamic> map) {
    final colors = _JsonColors.of(
      Theme.of(context).brightness,
      Theme.of(context).colorScheme.onSurface,
    );
    final mono = _mono(context);
    final trail = widget.trailingComma ? ',' : '';

    if (map.isEmpty) {
      return Text('{}$trail', style: mono.copyWith(color: colors.bracket));
    }

    if (!_expanded) {
      return GestureDetector(
        onTap: () => setState(() => _expanded = true),
        child: RichText(
          text: TextSpan(
            style: mono,
            children: [
              TextSpan(text: '{ ', style: TextStyle(color: colors.bracket)),
              TextSpan(
                text: '... ${map.length} ${map.length == 1 ? 'key' : 'keys'}',
                style: TextStyle(color: colors.muted),
              ),
              TextSpan(
                text: ' }$trail',
                style: TextStyle(color: colors.bracket),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = false),
          child: Text('{', style: mono.copyWith(color: colors.bracket)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: () {
              final entries = map.entries.toList();
              return List.generate(entries.length, (i) {
                final e = entries[i];
                final isLast = i == entries.length - 1;
                return _ObjectEntryRow(
                  mapKey: e.key,
                  value: e.value,
                  depth: widget.depth + 1,
                  trailingComma: !isLast,
                  colors: colors,
                  mono: mono,
                );
              });
            }(),
          ),
        ),
        Text('}$trail', style: mono.copyWith(color: colors.bracket)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Array
  // -------------------------------------------------------------------------

  Widget _buildArray(BuildContext context, List<dynamic> list) {
    final colors = _JsonColors.of(
      Theme.of(context).brightness,
      Theme.of(context).colorScheme.onSurface,
    );
    final mono = _mono(context);
    final trail = widget.trailingComma ? ',' : '';

    if (list.isEmpty) {
      return Text('[]$trail', style: mono.copyWith(color: colors.bracket));
    }

    if (!_expanded) {
      return GestureDetector(
        onTap: () => setState(() => _expanded = true),
        child: RichText(
          text: TextSpan(
            style: mono,
            children: [
              TextSpan(text: '[ ', style: TextStyle(color: colors.bracket)),
              TextSpan(
                text: '... ${list.length} '
                    '${list.length == 1 ? 'item' : 'items'}',
                style: TextStyle(color: colors.muted),
              ),
              TextSpan(
                text: ' ]$trail',
                style: TextStyle(color: colors.bracket),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = false),
          child: Text('[', style: mono.copyWith(color: colors.bracket)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(list.length, (i) {
              final isLast = i == list.length - 1;
              return _JsonNode(
                value: list[i],
                depth: widget.depth + 1,
                trailingComma: !isLast,
              );
            }),
          ),
        ),
        Text(']$trail', style: mono.copyWith(color: colors.bracket)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Primitive
  // -------------------------------------------------------------------------

  Widget _buildPrimitive(BuildContext context, dynamic value) {
    final colors = _JsonColors.of(
      Theme.of(context).brightness,
      Theme.of(context).colorScheme.onSurface,
    );
    final mono = _mono(context);
    final trail = widget.trailingComma ? ',' : '';

    final String text;
    final Color color;

    if (value == null) {
      text = 'null';
      color = colors.nullValue;
    } else if (value is bool) {
      text = value.toString();
      color = colors.boolean;
    } else if (value is num) {
      text = value.toString();
      color = colors.number;
    } else if (value is String) {
      text = '"${_escapeString(value)}"';
      color = colors.string;
    } else {
      text = value.toString();
      color = colors.string;
    }

    return RichText(
      text: TextSpan(
        style: mono,
        children: [
          TextSpan(text: text, style: TextStyle(color: color)),
          if (trail.isNotEmpty)
            TextSpan(
              text: trail,
              style: TextStyle(color: colors.punctuation),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Object entry row: "key": <value>
// ---------------------------------------------------------------------------

class _ObjectEntryRow extends StatelessWidget {
  const _ObjectEntryRow({
    required this.mapKey,
    required this.value,
    required this.depth,
    required this.trailingComma,
    required this.colors,
    required this.mono,
  });

  final String mapKey;
  final dynamic value;
  final int depth;
  final bool trailingComma;
  final _JsonColors colors;
  final TextStyle mono;

  @override
  Widget build(BuildContext context) {
    final keySpan = TextSpan(
      text: '"$mapKey"',
      style: TextStyle(color: colors.key),
    );
    final colonSpan = TextSpan(
      text: ': ',
      style: TextStyle(color: colors.punctuation),
    );

    // For primitive values render inline with the key.
    final isPrimitive = value is! Map && value is! List;
    if (isPrimitive) {
      final String valueText;
      final Color valueColor;

      if (value == null) {
        valueText = 'null';
        valueColor = colors.nullValue;
      } else if (value is bool) {
        valueText = value.toString();
        valueColor = colors.boolean;
      } else if (value is num) {
        valueText = value.toString();
        valueColor = colors.number;
      } else {
        valueText = '"${_escapeString(value.toString())}"';
        valueColor = colors.string;
      }

      final trail = trailingComma ? ',' : '';
      return RichText(
        text: TextSpan(
          style: mono,
          children: [
            keySpan,
            colonSpan,
            TextSpan(text: valueText, style: TextStyle(color: valueColor)),
            if (trail.isNotEmpty)
              TextSpan(
                text: trail,
                style: TextStyle(color: colors.punctuation),
              ),
          ],
        ),
      );
    }

    // For nested objects/arrays, render the key + colon on the same line as
    // the opening bracket by using a Row.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: mono,
            children: [keySpan, colonSpan],
          ),
        ),
        Flexible(
          child: _JsonNode(
            value: value,
            depth: depth,
            trailingComma: trailingComma,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _escapeString(String s) {
  return s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
}
