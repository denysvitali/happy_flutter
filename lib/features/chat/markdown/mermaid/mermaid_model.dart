/// Parsed Mermaid diagram models rendered natively by [MermaidDiagramView].
///
/// Only the subset agents commonly emit is modelled: flowcharts, sequence
/// diagrams and pie charts. Anything else is reported as unsupported so the
/// chat falls back to the plain code block.
library;

import 'dart:ui' show Color;

/// Base type of every parsed diagram.
sealed class MermaidDiagram {
  const MermaidDiagram();
}

/// Flow direction of a flowchart or subgraph.
enum MermaidDirection {
  /// Top to bottom (`TB` / `TD`).
  topDown,

  /// Bottom to top (`BT`).
  bottomUp,

  /// Left to right (`LR`).
  leftRight,

  /// Right to left (`RL`).
  rightLeft;

  /// Whether ranks advance horizontally.
  bool get isHorizontal => this == leftRight || this == rightLeft;

  /// Parses a Mermaid direction token; null when unrecognised.
  static MermaidDirection? tryParse(String token) {
    switch (token.trim().toUpperCase()) {
      case 'TB':
      case 'TD':
        return topDown;
      case 'BT':
        return bottomUp;
      case 'LR':
        return leftRight;
      case 'RL':
        return rightLeft;
    }
    return null;
  }
}

/// Visual shape of a flowchart node.
enum MermaidNodeShape {
  /// `A[text]`
  rect,

  /// `A(text)`
  round,

  /// `A([text])`
  stadium,

  /// `A[[text]]`
  subroutine,

  /// `A[(text)]`
  cylinder,

  /// `A((text))`
  circle,

  /// `A(((text)))`
  doubleCircle,

  /// `A>text]`
  asymmetric,

  /// `A{text}`
  rhombus,

  /// `A{{text}}`
  hexagon,

  /// `A[/text/]`
  parallelogram,

  /// `A[\text\]`
  parallelogramAlt,

  /// `A[/text\]`
  trapezoid,

  /// `A[\text/]`
  trapezoidAlt,
}

/// Subset of CSS-like style properties Mermaid diagrams use for colour.
class MermaidStyle {
  /// Creates a style.
  const MermaidStyle({
    this.fill,
    this.stroke,
    this.color,
    this.strokeWidth,
    this.dashed,
    this.bold,
  });

  /// Background fill.
  final Color? fill;

  /// Border / line colour.
  final Color? stroke;

  /// Text colour.
  final Color? color;

  /// Border / line width in logical pixels.
  final double? strokeWidth;

  /// Whether the border / line is dashed.
  final bool? dashed;

  /// Whether the label is bold.
  final bool? bold;

  /// Empty style.
  static const MermaidStyle none = MermaidStyle();

  /// Returns this style with every property set in [other] overriding it.
  MermaidStyle merge(MermaidStyle? other) {
    if (other == null) return this;
    return MermaidStyle(
      fill: other.fill ?? fill,
      stroke: other.stroke ?? stroke,
      color: other.color ?? color,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      dashed: other.dashed ?? dashed,
      bold: other.bold ?? bold,
    );
  }
}

/// A flowchart node.
class FlowNode {
  /// Creates a node.
  FlowNode(this.id, {String? label, this.shape = MermaidNodeShape.rect})
    : label = label ?? id;

  /// Identifier used by edges.
  final String id;

  /// Display text (may contain `\n`).
  String label;

  /// Display shape.
  MermaidNodeShape shape;

  /// `classDef` names applied to the node, in application order.
  final List<String> classes = [];

  /// Inline `style` override.
  MermaidStyle? style;

  /// Id of the innermost subgraph containing the node.
  String? subgraph;
}

/// Line style of a flowchart edge.
enum FlowEdgeLine {
  /// `-->`
  solid,

  /// `-.->`
  dotted,

  /// `==>`
  thick,

  /// `~~~`
  invisible,
}

/// Marker drawn at an edge end.
enum FlowEdgeMarker {
  /// No marker.
  none,

  /// Arrowhead.
  arrow,

  /// `--x`
  cross,

  /// `--o`
  circle,
}

/// A flowchart edge.
class FlowEdge {
  /// Creates an edge.
  FlowEdge({
    required this.from,
    required this.to,
    this.label,
    this.line = FlowEdgeLine.solid,
    this.startMarker = FlowEdgeMarker.none,
    this.endMarker = FlowEdgeMarker.arrow,
  });

  /// Source node id.
  String from;

  /// Target node id.
  String to;

  /// Optional label.
  final String? label;

  /// Line style.
  final FlowEdgeLine line;

  /// Marker at the source end.
  final FlowEdgeMarker startMarker;

  /// Marker at the target end.
  final FlowEdgeMarker endMarker;
}

/// A flowchart subgraph (cluster).
class FlowSubgraph {
  /// Creates a subgraph.
  FlowSubgraph(this.id, this.title, this.parent);

  /// Identifier.
  final String id;

  /// Display title.
  final String title;

  /// Enclosing subgraph id, if nested.
  final String? parent;

  /// Explicit `direction` inside the subgraph.
  MermaidDirection? direction;
}

/// `graph` / `flowchart` diagram.
class FlowchartDiagram extends MermaidDiagram {
  /// Creates a flowchart.
  FlowchartDiagram({
    required this.direction,
    required this.nodes,
    required this.edges,
    required this.subgraphs,
    required this.classDefs,
    required this.linkStyles,
    this.defaultLinkStyle,
  });

  /// Graph direction.
  final MermaidDirection direction;

  /// Nodes in declaration order.
  final Map<String, FlowNode> nodes;

  /// Edges in declaration order (index matters for `linkStyle`).
  final List<FlowEdge> edges;

  /// Subgraphs in declaration order.
  final Map<String, FlowSubgraph> subgraphs;

  /// `classDef` styles by name (`default` applies to every node).
  final Map<String, MermaidStyle> classDefs;

  /// `linkStyle` overrides by edge index.
  final Map<int, MermaidStyle> linkStyles;

  /// `linkStyle default` override.
  final MermaidStyle? defaultLinkStyle;

  /// Effective style of [node] (default class, classes, inline style).
  MermaidStyle styleOf(FlowNode node) {
    var style = classDefs['default'] ?? MermaidStyle.none;
    for (final name in node.classes) {
      style = style.merge(classDefs[name]);
    }
    return style.merge(node.style);
  }

  /// Effective style of the edge at [index].
  MermaidStyle edgeStyleOf(int index) =>
      (defaultLinkStyle ?? MermaidStyle.none).merge(linkStyles[index]);

  /// Effective style of the subgraph [id] (`style` / `class` on clusters).
  MermaidStyle clusterStyleOf(String id) {
    final style = clusterStyles[id];
    var result = MermaidStyle.none;
    for (final name in clusterClasses[id] ?? const <String>[]) {
      result = result.merge(classDefs[name]);
    }
    return result.merge(style);
  }

  /// Inline `style` on subgraph ids.
  final Map<String, MermaidStyle> clusterStyles = {};

  /// `class` assignments on subgraph ids.
  final Map<String, List<String>> clusterClasses = {};
}

/// Arrow kind of a sequence message.
enum SequenceArrow {
  /// `->>` / `-->>`
  arrow,

  /// `->` / `-->`
  open,

  /// `-x` / `--x`
  cross,

  /// `-)` / `--)`
  async,

  /// `<<->>` / `<<-->>`
  bidirectional,
}

/// A sequence-diagram participant.
class SequenceParticipant {
  /// Creates a participant.
  SequenceParticipant(this.id, this.label, {this.isActor = false});

  /// Identifier used by messages.
  final String id;

  /// Display text.
  String label;

  /// Whether rendered as an actor.
  bool isActor;
}

/// Base class of sequence-diagram events, in source order.
sealed class SequenceEvent {
  const SequenceEvent();
}

/// A message between two participants.
class SequenceMessage extends SequenceEvent {
  /// Creates a message.
  const SequenceMessage({
    required this.from,
    required this.to,
    required this.text,
    required this.arrow,
    required this.dotted,
    this.number,
  });

  /// Sender id.
  final String from;

  /// Receiver id.
  final String to;

  /// Message text.
  final String text;

  /// Arrow kind.
  final SequenceArrow arrow;

  /// Whether the line is dotted (a reply).
  final bool dotted;

  /// `autonumber` sequence number.
  final int? number;
}

/// Note placement.
enum SequenceNotePlacement {
  /// `Note left of A`
  leftOf,

  /// `Note right of A`
  rightOf,

  /// `Note over A[,B]`
  over,
}

/// A note.
class SequenceNote extends SequenceEvent {
  /// Creates a note.
  const SequenceNote({
    required this.placement,
    required this.participants,
    required this.text,
  });

  /// Placement.
  final SequenceNotePlacement placement;

  /// One or two participant ids.
  final List<String> participants;

  /// Note text.
  final String text;
}

/// Kind of a framed block.
enum SequenceBlockKind {
  /// `loop`
  loop,

  /// `alt`
  alt,

  /// `opt`
  opt,

  /// `par`
  par,

  /// `critical`
  critical,

  /// `break`
  breakBlock,

  /// `rect rgb(...)` background highlight.
  rect,
}

/// Opens a framed block.
class SequenceBlockStart extends SequenceEvent {
  /// Creates a block start.
  const SequenceBlockStart(this.kind, this.label, {this.color});

  /// Block kind.
  final SequenceBlockKind kind;

  /// Block label (condition).
  final String label;

  /// Background colour for `rect` blocks.
  final Color? color;
}

/// `else` / `and` / `option` divider inside a block.
class SequenceBlockDivider extends SequenceEvent {
  /// Creates a divider.
  const SequenceBlockDivider(this.label);

  /// Divider label.
  final String label;
}

/// Closes the innermost block.
class SequenceBlockEnd extends SequenceEvent {
  /// Creates a block end.
  const SequenceBlockEnd();
}

/// `sequenceDiagram`.
class SequenceDiagram extends MermaidDiagram {
  /// Creates a sequence diagram.
  const SequenceDiagram({required this.participants, required this.events});

  /// Participants in display order.
  final List<SequenceParticipant> participants;

  /// Events in source order.
  final List<SequenceEvent> events;
}

/// A pie slice.
class PieSlice {
  /// Creates a slice.
  const PieSlice(this.label, this.value);

  /// Label.
  final String label;

  /// Non-negative value.
  final double value;
}

/// `pie` chart.
class PieDiagram extends MermaidDiagram {
  /// Creates a pie chart.
  const PieDiagram({required this.slices, this.title, this.showData = false});

  /// Optional title.
  final String? title;

  /// Slices in declaration order.
  final List<PieSlice> slices;

  /// Whether raw values are shown in the legend.
  final bool showData;
}
