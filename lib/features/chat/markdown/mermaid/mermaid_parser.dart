/// Tolerant parser for the Mermaid subset rendered in chat.
library;

import 'dart:ui' show Color;

import 'mermaid_model.dart';

/// Largest source accepted for rendering. Bigger blocks stay code blocks.
const int mermaidMaxSourceChars = 20000;

/// Largest flowchart (nodes) accepted for rendering.
const int mermaidMaxNodes = 250;

/// Largest flowchart (edges) accepted for rendering.
const int mermaidMaxEdges = 500;

/// Largest sequence diagram (participants) accepted for rendering.
const int mermaidMaxParticipants = 30;

/// Largest sequence diagram (events) accepted for rendering.
const int mermaidMaxEvents = 400;

/// Raised for sources that cannot be rendered natively.
class MermaidParseException implements Exception {
  /// Creates an exception.
  const MermaidParseException(this.message, {this.unsupported = false});

  /// Human-readable (English) reason, used for diagnostics only.
  final String message;

  /// Whether the diagram type itself is not supported (vs. malformed).
  final bool unsupported;

  @override
  String toString() => 'MermaidParseException: $message';
}

/// Parses [source] into a [MermaidDiagram].
///
/// Throws [MermaidParseException] for unsupported types, malformed
/// statements the renderer cannot represent, or diagrams over the size caps.
MermaidDiagram parseMermaid(String source) {
  if (source.length > mermaidMaxSourceChars) {
    throw const MermaidParseException('Diagram is too large');
  }
  final lines = _cleanLines(source);
  if (lines.isEmpty) {
    throw const MermaidParseException('Empty diagram');
  }
  final header = lines.first;
  final keyword = header.split(RegExp(r'\s+')).first;
  switch (keyword) {
    case 'graph':
    case 'flowchart':
    case 'flowchart-elk':
      return _FlowchartParser(header, lines.skip(1)).parse();
    case 'sequenceDiagram':
      return _parseSequence(lines.skip(1));
    case 'pie':
      return _parsePie(header, lines.skip(1));
  }
  throw MermaidParseException(
    'Unsupported diagram type "$keyword"',
    unsupported: true,
  );
}

/// Strips comments, directives, front matter and blank lines.
List<String> _cleanLines(String source) {
  var text = source.replaceAll('\r\n', '\n');
  // `%%{init: ...}%%` directives may span lines.
  text = text.replaceAll(RegExp(r'%%\{[\s\S]*?\}%%'), '');
  final raw = text.split('\n');
  final out = <String>[];
  var i = 0;
  // YAML front matter (`---` ... `---`) before the diagram keyword.
  while (i < raw.length && raw[i].trim().isEmpty) {
    i++;
  }
  if (i < raw.length && raw[i].trim() == '---') {
    i++;
    while (i < raw.length && raw[i].trim() != '---') {
      i++;
    }
    i++;
  }
  for (; i < raw.length; i++) {
    final line = raw[i].trim();
    if (line.isEmpty || line.startsWith('%%')) continue;
    out.add(line);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Labels, colours and styles
// ---------------------------------------------------------------------------

final RegExp _brTag = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _htmlTag = RegExp(r'</?[A-Za-z][^<>]*>');
final RegExp _faIcon = RegExp(r'fa[bklrs]?:fa-[\w-]+\s*');

/// Normalises a Mermaid label to plain display text.
String cleanMermaidLabel(String raw) {
  var text = raw.trim();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    text = text.substring(1, text.length - 1);
  }
  // Markdown strings: "`**bold** text`".
  if (text.length >= 2 && text.startsWith('`') && text.endsWith('`')) {
    text = text.substring(1, text.length - 1).replaceAll(RegExp(r'[*_]'), '');
  }
  text = text
      .replaceAll(_brTag, '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(_htmlTag, '')
      .replaceAll(_faIcon, '')
      .replaceAll('#quot;', '"')
      .replaceAll('#amp;', '&')
      .replaceAll('#lt;', '<')
      .replaceAll('#gt;', '>')
      .replaceAll('#35;', '#')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
  return text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
}

const Map<String, int> _namedColors = {
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'red': 0xFFFF0000,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'yellow': 0xFFFFFF00,
  'orange': 0xFFFFA500,
  'purple': 0xFF800080,
  'pink': 0xFFFFC0CB,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'silver': 0xFFC0C0C0,
  'brown': 0xFFA52A2A,
  'cyan': 0xFF00FFFF,
  'aqua': 0xFF00FFFF,
  'magenta': 0xFFFF00FF,
  'fuchsia': 0xFFFF00FF,
  'lime': 0xFF00FF00,
  'navy': 0xFF000080,
  'teal': 0xFF008080,
  'olive': 0xFF808000,
  'maroon': 0xFF800000,
  'gold': 0xFFFFD700,
  'coral': 0xFFFF7F50,
  'salmon': 0xFFFA8072,
  'tomato': 0xFFFF6347,
  'violet': 0xFFEE82EE,
  'indigo': 0xFF4B0082,
  'crimson': 0xFFDC143C,
  'orchid': 0xFFDA70D6,
  'plum': 0xFFDDA0DD,
  'khaki': 0xFFF0E68C,
  'beige': 0xFFF5F5DC,
  'ivory': 0xFFFFFFF0,
  'lavender': 0xFFE6E6FA,
  'turquoise': 0xFF40E0D0,
  'skyblue': 0xFF87CEEB,
  'steelblue': 0xFF4682B4,
  'royalblue': 0xFF4169E1,
  'darkblue': 0xFF00008B,
  'darkgreen': 0xFF006400,
  'darkred': 0xFF8B0000,
  'darkorange': 0xFFFF8C00,
  'darkgray': 0xFFA9A9A9,
  'darkgrey': 0xFFA9A9A9,
  'lightblue': 0xFFADD8E6,
  'lightgreen': 0xFF90EE90,
  'lightgray': 0xFFD3D3D3,
  'lightgrey': 0xFFD3D3D3,
  'lightyellow': 0xFFFFFFE0,
  'lightpink': 0xFFFFB6C1,
  'lightcoral': 0xFFF08080,
  'lightsalmon': 0xFFFFA07A,
  'palegreen': 0xFF98FB98,
  'mediumpurple': 0xFF9370DB,
  'seagreen': 0xFF2E8B57,
  'forestgreen': 0xFF228B22,
  'limegreen': 0xFF32CD32,
  'dodgerblue': 0xFF1E90FF,
  'deepskyblue': 0xFF00BFFF,
  'hotpink': 0xFFFF69B4,
  'deeppink': 0xFFFF1493,
  'slategray': 0xFF708090,
  'slategrey': 0xFF708090,
  'whitesmoke': 0xFFF5F5F5,
  'gainsboro': 0xFFDCDCDC,
};

/// Parses a CSS colour (`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()`,
/// `rgba()`, or a common colour name). Returns null when unrecognised.
Color? parseMermaidColor(String raw) {
  final value = raw.trim().toLowerCase().replaceAll('!important', '').trim();
  if (value.isEmpty || value == 'none' || value == 'transparent') {
    return value == 'none' || value == 'transparent'
        ? const Color(0x00000000)
        : null;
  }
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex)) return null;
    if (hex.length == 3 || hex.length == 4) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
    if (hex.length == 8) {
      final rgb = int.parse(hex.substring(0, 6), radix: 16);
      final a = int.parse(hex.substring(6), radix: 16);
      return Color((a << 24) | rgb);
    }
    return null;
  }
  final fn = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(value);
  if (fn != null) {
    final parts = fn
        .group(1)!
        .split(RegExp(r'[\s,/]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 3) return null;
    int channel(String p) {
      if (p.endsWith('%')) {
        final v = double.tryParse(p.substring(0, p.length - 1)) ?? 0;
        return (v * 2.55).round().clamp(0, 255);
      }
      return (double.tryParse(p) ?? 0).round().clamp(0, 255);
    }

    var alpha = 255;
    if (parts.length >= 4) {
      final p = parts[3];
      final a = p.endsWith('%')
          ? (double.tryParse(p.substring(0, p.length - 1)) ?? 100) / 100
          : double.tryParse(p) ?? 1;
      alpha = (a.clamp(0, 1) * 255).round();
    }
    return Color.fromARGB(
      alpha,
      channel(parts[0]),
      channel(parts[1]),
      channel(parts[2]),
    );
  }
  final named = _namedColors[value];
  return named == null ? null : Color(named);
}

/// Parses `fill:#f9f,stroke:#333,stroke-width:2px,color:#fff`.
MermaidStyle parseMermaidStyle(String raw) {
  Color? fill;
  Color? stroke;
  Color? color;
  double? width;
  bool? dashed;
  bool? bold;
  for (final decl in raw.split(RegExp(r'[,;]'))) {
    final idx = decl.indexOf(':');
    if (idx <= 0) continue;
    final key = decl.substring(0, idx).trim().toLowerCase();
    final value = decl.substring(idx + 1).trim();
    switch (key) {
      case 'fill':
      case 'background':
      case 'background-color':
        fill = parseMermaidColor(value) ?? fill;
      case 'stroke':
        stroke = parseMermaidColor(value) ?? stroke;
      case 'color':
        color = parseMermaidColor(value) ?? color;
      case 'stroke-width':
        width = double.tryParse(value.replaceAll(RegExp(r'[a-z%]'), ''));
      case 'stroke-dasharray':
        dashed = value.isNotEmpty && value != '0' && value != 'none';
      case 'font-weight':
        bold = value == 'bold' || (int.tryParse(value) ?? 400) >= 600;
    }
  }
  return MermaidStyle(
    fill: fill,
    stroke: stroke,
    color: color,
    strokeWidth: width,
    dashed: dashed,
    bold: bold,
  );
}

// ---------------------------------------------------------------------------
// Flowchart
// ---------------------------------------------------------------------------

/// Node shapes ordered so longer delimiters are tried first.
const List<(String, List<String>, MermaidNodeShape?)> _shapeDelimiters = [
  ('(((', [')))'], MermaidNodeShape.doubleCircle),
  ('((', ['))'], MermaidNodeShape.circle),
  ('([', ['])'], MermaidNodeShape.stadium),
  ('[[', [']]'], MermaidNodeShape.subroutine),
  ('[(', [')]'], MermaidNodeShape.cylinder),
  // Parallelogram / trapezoid variants resolve from the closing delimiter.
  ('[/', ['/]', r'\]'], null),
  (r'[\', [r'\]', '/]'], null),
  ('{{', ['}}'], MermaidNodeShape.hexagon),
  ('{', ['}'], MermaidNodeShape.rhombus),
  ('(', [')'], MermaidNodeShape.round),
  ('[', [']'], MermaidNodeShape.rect),
  ('>', [']'], MermaidNodeShape.asymmetric),
];

final RegExp _plainArrow = RegExp(
  r'^(<)?(-{2,}>|-{3,}|={2,}>|={3,}|-\.+->|-\.+-|~{3,}|-{2,}[xo](?![\w])|={2,}[xo](?![\w])|-\.+-[xo](?![\w]))',
);

final RegExp _textArrow = RegExp(
  r'^(<)?(--|==|-\.)(?![->.=])\s*(.+?)\s*(-{2,}>|-{3,}|={2,}>|={3,}|\.-+>|\.-+|-{2,}[xo](?![\w])|={2,}[xo](?![\w]))',
);

final RegExp _nodeIdChar = RegExp(r'[A-Za-z0-9_À-￿]');

class _FlowchartParser {
  _FlowchartParser(this.header, this.lines);

  final String header;
  final Iterable<String> lines;

  final nodes = <String, FlowNode>{};
  final edges = <FlowEdge>[];
  final subgraphs = <String, FlowSubgraph>{};
  final classDefs = <String, MermaidStyle>{};
  final linkStyles = <int, MermaidStyle>{};
  final nodeStyles = <String, MermaidStyle>{};
  final classAssignments = <String, List<String>>{};
  MermaidStyle? defaultLinkStyle;
  final stack = <String>[];
  int anonSubgraphs = 0;

  FlowchartDiagram parse() {
    final headerParts = header.split(';').first.trim().split(RegExp(r'\s+'));
    final direction = headerParts.length > 1
        ? MermaidDirection.tryParse(headerParts[1]) ?? MermaidDirection.topDown
        : MermaidDirection.topDown;
    // Statements after the header token on the same line (`graph LR; A-->B`).
    final headerRest = header.contains(';')
        ? header.substring(header.indexOf(';') + 1)
        : '';
    for (final line in [headerRest, ...lines]) {
      for (final statement in _splitStatements(line)) {
        _statement(statement);
      }
    }

    // Edges may reference subgraph ids: redirect them to member nodes.
    for (final id in subgraphs.keys) {
      final members = nodes.values.where((n) => _isInside(n.subgraph, id));
      if (members.isEmpty) continue;
      final placeholder = nodes[id];
      if (placeholder != null && placeholder.subgraph != id) {
        nodes.remove(id);
      }
      for (final edge in edges) {
        if (edge.from == id) edge.from = members.last.id;
        if (edge.to == id) edge.to = members.first.id;
      }
    }

    for (final entry in classAssignments.entries) {
      final node = nodes[entry.key];
      if (node != null) node.classes.addAll(entry.value);
    }
    final diagram = FlowchartDiagram(
      direction: direction,
      nodes: nodes,
      edges: edges
          .where((e) => nodes.containsKey(e.from) && nodes.containsKey(e.to))
          .toList(),
      subgraphs: subgraphs,
      classDefs: classDefs,
      linkStyles: linkStyles,
      defaultLinkStyle: defaultLinkStyle,
    );
    for (final entry in nodeStyles.entries) {
      final node = nodes[entry.key];
      if (node != null) {
        node.style = (node.style ?? MermaidStyle.none).merge(entry.value);
      } else if (subgraphs.containsKey(entry.key)) {
        diagram.clusterStyles[entry.key] = entry.value;
      }
    }
    for (final entry in classAssignments.entries) {
      if (!nodes.containsKey(entry.key) && subgraphs.containsKey(entry.key)) {
        diagram.clusterClasses[entry.key] = entry.value;
      }
    }
    if (nodes.isEmpty) {
      throw const MermaidParseException('Flowchart has no nodes');
    }
    if (nodes.length > mermaidMaxNodes || edges.length > mermaidMaxEdges) {
      throw const MermaidParseException('Diagram is too large');
    }
    return diagram;
  }

  bool _isInside(String? subgraph, String ancestor) {
    var current = subgraph;
    while (current != null) {
      if (current == ancestor) return true;
      current = subgraphs[current]?.parent;
    }
    return false;
  }

  /// Splits on `;` outside quotes and brackets.
  Iterable<String> _splitStatements(String line) sync* {
    var depth = 0;
    var inQuote = false;
    var start = 0;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') inQuote = !inQuote;
      if (inQuote) continue;
      if (c == '[' || c == '(' || c == '{') depth++;
      if ((c == ']' || c == ')' || c == '}') && depth > 0) depth--;
      if (c == ';' && depth == 0) {
        final s = line.substring(start, i).trim();
        if (s.isNotEmpty) yield s;
        start = i + 1;
      }
    }
    final s = line.substring(start).trim();
    if (s.isNotEmpty) yield s;
  }

  void _statement(String s) {
    final lower = s.toLowerCase();
    if (lower == 'end') {
      if (stack.isNotEmpty) stack.removeLast();
      return;
    }
    if (lower.startsWith('subgraph')) {
      _subgraph(s.substring('subgraph'.length).trim());
      return;
    }
    if (lower.startsWith('direction ')) {
      final dir = MermaidDirection.tryParse(s.substring(10));
      if (dir != null && stack.isNotEmpty) {
        subgraphs[stack.last]!.direction = dir;
      }
      return;
    }
    if (lower.startsWith('classdef ')) {
      final m = RegExp(
        r'^classDef\s+(\S+)\s+(.*)$',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) {
        final style = parseMermaidStyle(m.group(2)!);
        for (final name in m.group(1)!.split(',')) {
          classDefs[name.trim()] = style;
        }
      }
      return;
    }
    if (lower.startsWith('class ')) {
      final m = RegExp(
        r'^class\s+(\S+)\s+(\S+)',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) {
        for (final id in m.group(1)!.split(',')) {
          classAssignments.putIfAbsent(id.trim(), () => []).add(m.group(2)!);
        }
      }
      return;
    }
    if (lower.startsWith('style ')) {
      final m = RegExp(
        r'^style\s+(\S+)\s+(.*)$',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) {
        final id = m.group(1)!;
        nodeStyles[id] = (nodeStyles[id] ?? MermaidStyle.none).merge(
          parseMermaidStyle(m.group(2)!),
        );
      }
      return;
    }
    if (lower.startsWith('linkstyle ')) {
      final m = RegExp(
        r'^linkStyle\s+(\S+)\s+(.*)$',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) {
        final style = parseMermaidStyle(m.group(2)!);
        final target = m.group(1)!;
        if (target == 'default') {
          defaultLinkStyle = style;
        } else {
          for (final idx in target.split(',')) {
            final i = int.tryParse(idx.trim());
            if (i != null) linkStyles[i] = style;
          }
        }
      }
      return;
    }
    if (lower.startsWith('click ') ||
        lower.startsWith('accTitle'.toLowerCase()) ||
        lower.startsWith('accdescr') ||
        lower.startsWith('title ')) {
      return;
    }
    _chain(s);
  }

  void _subgraph(String rest) {
    String id;
    String title;
    final bracket = RegExp(r'^([^\s\[]+)\s*\[(.*)\]$').firstMatch(rest);
    if (bracket != null) {
      id = bracket.group(1)!;
      title = cleanMermaidLabel(bracket.group(2)!);
    } else if (rest.startsWith('"')) {
      title = cleanMermaidLabel(rest);
      id = 'subgraph_${anonSubgraphs++}';
    } else if (rest.isEmpty) {
      id = 'subgraph_${anonSubgraphs++}';
      title = '';
    } else if (!rest.contains(' ')) {
      id = rest;
      title = rest;
    } else {
      title = cleanMermaidLabel(rest);
      id = rest;
    }
    subgraphs.putIfAbsent(
      id,
      () => FlowSubgraph(id, title, stack.isEmpty ? null : stack.last),
    );
    stack.add(id);
  }

  void _chain(String s) {
    final scanner = _Scanner(s);
    var previous = _nodeGroup(scanner);
    if (previous.isEmpty) {
      throw MermaidParseException('Unrecognised statement: $s');
    }
    while (true) {
      scanner.skipSpace();
      if (scanner.done) break;
      final edge = _edge(scanner);
      if (edge == null) {
        throw MermaidParseException('Unrecognised statement: $s');
      }
      scanner.skipSpace();
      final next = _nodeGroup(scanner);
      if (next.isEmpty) {
        throw MermaidParseException('Edge without target: $s');
      }
      for (final from in previous) {
        for (final to in next) {
          edges.add(
            FlowEdge(
              from: from,
              to: to,
              label: edge.label,
              line: edge.line,
              startMarker: edge.start,
              endMarker: edge.end,
            ),
          );
        }
      }
      previous = next;
    }
  }

  List<String> _nodeGroup(_Scanner scanner) {
    final ids = <String>[];
    while (true) {
      scanner.skipSpace();
      final id = _node(scanner);
      if (id == null) break;
      ids.add(id);
      scanner.skipSpace();
      if (scanner.peek == '&') {
        scanner.pos++;
        continue;
      }
      break;
    }
    return ids;
  }

  String? _node(_Scanner scanner) {
    final s = scanner.text;
    final start = scanner.pos;
    var i = start;
    while (i < s.length) {
      final c = s[i];
      if (_nodeIdChar.hasMatch(c)) {
        i++;
        continue;
      }
      // Hyphens / dots inside ids (`api-gw`), but never the start of an arrow.
      if ((c == '-' || c == '.') &&
          i > start &&
          i + 1 < s.length &&
          _nodeIdChar.hasMatch(s[i + 1])) {
        i++;
        continue;
      }
      break;
    }
    if (i == start) return null;
    final id = s.substring(start, i);
    scanner.pos = i;

    String? label;
    MermaidNodeShape? shape;
    for (final (open, closes, fixedShape) in _shapeDelimiters) {
      if (!s.startsWith(open, scanner.pos)) continue;
      final bodyStart = scanner.pos + open.length;
      int? closeAt;
      String? close;
      var quoted = false;
      var j = bodyStart;
      while (j < s.length && s[j] == ' ') {
        j++;
      }
      if (j < s.length && s[j] == '"') {
        quoted = true;
        final endQuote = s.indexOf('"', j + 1);
        if (endQuote < 0) continue;
        j = endQuote + 1;
      }
      for (final candidate in closes) {
        final at = s.indexOf(candidate, quoted ? j : bodyStart);
        if (at >= 0 && (closeAt == null || at < closeAt)) {
          closeAt = at;
          close = candidate;
        }
      }
      if (closeAt == null || close == null) continue;
      label = cleanMermaidLabel(s.substring(bodyStart, closeAt));
      shape =
          fixedShape ??
          switch ((open, close)) {
            ('[/', '/]') => MermaidNodeShape.parallelogram,
            ('[/', r'\]') => MermaidNodeShape.trapezoid,
            (r'[\', r'\]') => MermaidNodeShape.parallelogramAlt,
            _ => MermaidNodeShape.trapezoidAlt,
          };
      scanner.pos = closeAt + close.length;
      break;
    }
    // Newer `A@{ shape: ..., label: "..." }` syntax: keep the label only.
    if (shape == null && s.startsWith('@{', scanner.pos)) {
      final end = s.indexOf('}', scanner.pos);
      if (end > 0) {
        final body = s.substring(scanner.pos + 2, end);
        final lm = RegExp(r'label:\s*"([^"]*)"').firstMatch(body);
        if (lm != null) label = cleanMermaidLabel(lm.group(1)!);
        final sm = RegExp(r'shape:\s*([\w-]+)').firstMatch(body);
        shape = switch (sm?.group(1)) {
          'circle' || 'circ' => MermaidNodeShape.circle,
          'diam' || 'diamond' || 'decision' => MermaidNodeShape.rhombus,
          'rounded' || 'event' => MermaidNodeShape.round,
          'stadium' || 'terminal' || 'pill' => MermaidNodeShape.stadium,
          'cyl' ||
          'cylinder' ||
          'database' ||
          'db' => MermaidNodeShape.cylinder,
          'hex' || 'hexagon' || 'prepare' => MermaidNodeShape.hexagon,
          _ => MermaidNodeShape.rect,
        };
        scanner.pos = end + 1;
      }
    }

    final node = nodes.putIfAbsent(id, () => FlowNode(id));
    if (label != null) node.label = label;
    if (shape != null) node.shape = shape;
    if (stack.isNotEmpty &&
        node.subgraph == null &&
        !subgraphs.containsKey(id)) {
      node.subgraph = stack.last;
    }

    if (s.startsWith(':::', scanner.pos)) {
      final m = RegExp(r':::([\w-]+)').matchAsPrefix(s, scanner.pos);
      if (m != null) {
        classAssignments.putIfAbsent(id, () => []).add(m.group(1)!);
        scanner.pos = m.end;
      }
    }
    return id;
  }

  _ParsedEdge? _edge(_Scanner scanner) {
    final rest = scanner.text.substring(scanner.pos);
    String? label;
    String body;
    bool hasStart;
    final plain = _plainArrow.firstMatch(rest);
    if (plain != null) {
      hasStart = plain.group(1) != null;
      body = plain.group(2)!;
      scanner.pos += plain.end;
      scanner.skipSpace();
      if (scanner.peek == '|') {
        final end = scanner.text.indexOf('|', scanner.pos + 1);
        if (end < 0) return null;
        label = cleanMermaidLabel(scanner.text.substring(scanner.pos + 1, end));
        scanner.pos = end + 1;
      }
    } else {
      final text = _textArrow.firstMatch(rest);
      if (text == null) return null;
      hasStart = text.group(1) != null;
      body = text.group(2)! + text.group(4)!;
      label = cleanMermaidLabel(text.group(3)!);
      scanner.pos += text.end;
    }
    final line = body.startsWith('~')
        ? FlowEdgeLine.invisible
        : body.contains('=')
        ? FlowEdgeLine.thick
        : body.contains('.')
        ? FlowEdgeLine.dotted
        : FlowEdgeLine.solid;
    final last = body[body.length - 1];
    final end = switch (last) {
      '>' => FlowEdgeMarker.arrow,
      'x' => FlowEdgeMarker.cross,
      'o' => FlowEdgeMarker.circle,
      _ => FlowEdgeMarker.none,
    };
    final start = hasStart ? FlowEdgeMarker.arrow : FlowEdgeMarker.none;
    return _ParsedEdge(
      label: (label?.isEmpty ?? true) ? null : label,
      line: line,
      start: start,
      end: end,
    );
  }
}

class _ParsedEdge {
  const _ParsedEdge({
    required this.label,
    required this.line,
    required this.start,
    required this.end,
  });

  final String? label;
  final FlowEdgeLine line;
  final FlowEdgeMarker start;
  final FlowEdgeMarker end;
}

class _Scanner {
  _Scanner(this.text);

  final String text;
  int pos = 0;

  bool get done => pos >= text.length;

  String? get peek => done ? null : text[pos];

  void skipSpace() {
    while (!done && (text[pos] == ' ' || text[pos] == '\t')) {
      pos++;
    }
  }
}

// ---------------------------------------------------------------------------
// Sequence diagram
// ---------------------------------------------------------------------------

final RegExp _participantLine = RegExp(
  r'^(?:create\s+)?(participant|actor)\s+(.+?)(?:\s+as\s+(.+))?$',
  caseSensitive: false,
);

final RegExp _messageLine = RegExp(
  r'^(.+?)\s*(<<-->>|<<->>|-->>|->>|-->|->|--x|-x|--\)|-\))\s*([+-]?)\s*(.+?)\s*:(.*)$',
);

final RegExp _noteLine = RegExp(
  r'^note\s+(left of|right of|over)\s+([^:]+?)\s*:(.*)$',
  caseSensitive: false,
);

SequenceDiagram _parseSequence(Iterable<String> lines) {
  final participants = <String, SequenceParticipant>{};
  final events = <SequenceEvent>[];
  var autonumber = false;
  var counter = 0;
  // Tracks `box` vs. framed block nesting so `end` closes the right one.
  final openers = <bool>[];

  SequenceParticipant participant(String rawId) {
    final id = rawId.trim();
    return participants.putIfAbsent(
      id,
      () => SequenceParticipant(id, cleanMermaidLabel(id)),
    );
  }

  for (final line in lines) {
    final lower = line.toLowerCase();
    if (lower.startsWith('autonumber')) {
      autonumber = true;
      continue;
    }
    if (lower.startsWith('title ') ||
        lower.startsWith('acctitle') ||
        lower.startsWith('accdescr') ||
        lower.startsWith('activate ') ||
        lower.startsWith('deactivate ') ||
        lower.startsWith('destroy ') ||
        lower.startsWith('link ') ||
        lower.startsWith('links ')) {
      continue;
    }
    final p = _participantLine.firstMatch(line);
    if (p != null) {
      final entry = participant(p.group(2)!);
      if (p.group(3) != null) entry.label = cleanMermaidLabel(p.group(3)!);
      entry.isActor = p.group(1)!.toLowerCase() == 'actor';
      continue;
    }
    if (lower == 'box' || lower.startsWith('box ')) {
      openers.add(false);
      continue;
    }
    if (lower == 'end') {
      if (openers.isNotEmpty && openers.removeLast()) {
        events.add(const SequenceBlockEnd());
      }
      continue;
    }
    final block = RegExp(
      r'^(loop|alt|opt|par|critical|break|rect)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (block != null) {
      final keyword = block.group(1)!.toLowerCase();
      final kind = switch (keyword) {
        'loop' => SequenceBlockKind.loop,
        'alt' => SequenceBlockKind.alt,
        'opt' => SequenceBlockKind.opt,
        'par' => SequenceBlockKind.par,
        'critical' => SequenceBlockKind.critical,
        'break' => SequenceBlockKind.breakBlock,
        _ => SequenceBlockKind.rect,
      };
      final rest = block.group(2)!;
      events.add(
        SequenceBlockStart(
          kind,
          kind == SequenceBlockKind.rect ? '' : cleanMermaidLabel(rest),
          color: kind == SequenceBlockKind.rect
              ? parseMermaidColor(rest)
              : null,
        ),
      );
      openers.add(true);
      continue;
    }
    final divider = RegExp(
      r'^(else|and|option)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (divider != null) {
      events.add(SequenceBlockDivider(cleanMermaidLabel(divider.group(2)!)));
      continue;
    }
    final note = _noteLine.firstMatch(line);
    if (note != null) {
      final placement = switch (note.group(1)!.toLowerCase()) {
        'left of' => SequenceNotePlacement.leftOf,
        'right of' => SequenceNotePlacement.rightOf,
        _ => SequenceNotePlacement.over,
      };
      final ids = note
          .group(2)!
          .split(',')
          .map((id) => participant(id).id)
          .take(2)
          .toList();
      events.add(
        SequenceNote(
          placement: placement,
          participants: ids,
          text: cleanMermaidLabel(note.group(3)!),
        ),
      );
      continue;
    }
    final message = _messageLine.firstMatch(line);
    if (message != null) {
      final arrowToken = message.group(2)!;
      final arrow = switch (arrowToken.replaceAll('-', '')) {
        '>>' => SequenceArrow.arrow,
        '>' => SequenceArrow.open,
        'x' => SequenceArrow.cross,
        ')' => SequenceArrow.async,
        _ => SequenceArrow.bidirectional,
      };
      events.add(
        SequenceMessage(
          from: participant(message.group(1)!).id,
          to: participant(message.group(4)!).id,
          text: cleanMermaidLabel(message.group(5)!),
          arrow: arrow,
          dotted: arrowToken.contains('--'),
          number: autonumber ? ++counter : null,
        ),
      );
      continue;
    }
    throw MermaidParseException('Unrecognised statement: $line');
  }
  // Close blocks left open by a truncated source.
  for (final opener in openers.reversed) {
    if (opener) events.add(const SequenceBlockEnd());
  }
  if (participants.isEmpty) {
    throw const MermaidParseException('Sequence diagram has no participants');
  }
  if (participants.length > mermaidMaxParticipants ||
      events.length > mermaidMaxEvents) {
    throw const MermaidParseException('Diagram is too large');
  }
  return SequenceDiagram(
    participants: participants.values.toList(),
    events: events,
  );
}

// ---------------------------------------------------------------------------
// Pie
// ---------------------------------------------------------------------------

PieDiagram _parsePie(String header, Iterable<String> lines) {
  var showData = header.contains('showData');
  String? title;
  final headerTitle = RegExp(r'\btitle\s+(.+)$').firstMatch(header);
  if (headerTitle != null) title = cleanMermaidLabel(headerTitle.group(1)!);
  final slices = <PieSlice>[];
  for (final line in lines) {
    if (line == 'showData') {
      showData = true;
      continue;
    }
    if (line.startsWith('title ')) {
      title = cleanMermaidLabel(line.substring(6));
      continue;
    }
    final m = RegExp(
      r'^"([^"]*)"\s*:\s*([0-9]*\.?[0-9]+)\s*$',
    ).firstMatch(line);
    if (m == null) {
      throw MermaidParseException('Unrecognised statement: $line');
    }
    slices.add(
      PieSlice(cleanMermaidLabel(m.group(1)!), double.parse(m.group(2)!)),
    );
  }
  if (slices.isEmpty || slices.every((s) => s.value <= 0)) {
    throw const MermaidParseException('Pie chart has no data');
  }
  return PieDiagram(title: title, slices: slices, showData: showData);
}
