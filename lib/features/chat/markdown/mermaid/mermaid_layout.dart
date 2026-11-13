/// Lays out parsed Mermaid diagrams into paintable [MermaidScene]s.
///
/// Flowcharts use a compact layered (Sugiyama-style) layout: cycle breaking,
/// longest-path ranking, dummy vertices for long edges, barycentric crossing
/// reduction and iterative neighbour alignment. Subgraphs are laid out
/// recursively as compound nodes so cluster boxes never overlap.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mermaid_model.dart';
import 'mermaid_scene.dart';

/// Builds the scene for [diagram].
MermaidScene buildMermaidScene(MermaidDiagram diagram, MermaidTheme theme) {
  return switch (diagram) {
    FlowchartDiagram() => _FlowchartLayout(diagram, theme).build(),
    SequenceDiagram() => _buildSequence(diagram, theme),
    PieDiagram() => _buildPie(diagram, theme),
  };
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

Path _polygon(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Catmull-Rom spline through [points], as cubic Béziers.
Path _smoothPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) {
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = i == 0 ? points[0] : points[i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

Offset _unit(Offset v) {
  final d = v.distance;
  return d < 1e-6 ? const Offset(1, 0) : v / d;
}

/// Adds an end marker at [tip] pointing along [direction].
void _addMarker(
  List<MermaidOp> ops,
  FlowEdgeMarker marker,
  Offset tip,
  Offset direction,
  Color color,
  double width,
  Color surface,
) {
  final u = _unit(direction);
  final n = Offset(-u.dy, u.dx);
  switch (marker) {
    case FlowEdgeMarker.none:
      return;
    case FlowEdgeMarker.arrow:
      final len = 9 + width;
      final half = 4.5 + width * 0.6;
      final base = tip - u * len;
      ops.add(
        MermaidPathOp(
          _polygon([tip, base + n * half, base - n * half]),
          fill: color,
          stroke: color,
          strokeWidth: 1,
        ),
      );
    case FlowEdgeMarker.cross:
      final c = tip - u * 6;
      const s = 4.5;
      final path = Path()
        ..moveTo((c - u * s - n * s).dx, (c - u * s - n * s).dy)
        ..lineTo((c + u * s + n * s).dx, (c + u * s + n * s).dy)
        ..moveTo((c - u * s + n * s).dx, (c - u * s + n * s).dy)
        ..lineTo((c + u * s - n * s).dx, (c + u * s - n * s).dy);
      ops.add(MermaidPathOp(path, stroke: color, strokeWidth: width + 0.5));
    case FlowEdgeMarker.circle:
      final c = tip - u * 4.5;
      ops.add(
        MermaidPathOp(
          Path()..addOval(Rect.fromCircle(center: c, radius: 4.5)),
          fill: surface,
          stroke: color,
          strokeWidth: width,
        ),
      );
  }
}

/// Text label on a rounded background pill, centred at [center].
void _addLabelBox(
  List<MermaidOp> ops,
  TextPainter painter,
  Offset center, {
  required Color background,
  Color? border,
}) {
  final rect = Rect.fromCenter(
    center: center,
    width: painter.width + 10,
    height: painter.height + 4,
  );
  ops.add(
    MermaidPathOp(
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6))),
      fill: background,
      stroke: border,
      strokeWidth: border == null ? 0 : 1,
    ),
  );
  ops.add(
    MermaidTextOp(
      painter,
      center - Offset(painter.width / 2, painter.height / 2),
    ),
  );
}

// ---------------------------------------------------------------------------
// Layered layout
// ---------------------------------------------------------------------------

class _LevelEdge {
  const _LevelEdge(this.u, this.v, this.index, this.label);

  final int u;
  final int v;
  final int index;
  final Size? label;
}

class _LevelLayout {
  _LevelLayout(this.centers, this.size, this.waypoints, this.labelAnchors);

  final List<Offset> centers;
  final Size size;
  final Map<int, List<Offset>> waypoints;
  final Map<int, Offset> labelAnchors;
}

const double _itemGap = 30;
const double _dummyGap = 14;
const double _rankGap = 48;

_LevelLayout _layered(
  List<Size> sizes,
  List<_LevelEdge> edges,
  MermaidDirection direction,
) {
  final n = sizes.length;
  if (n == 0) return _LevelLayout(const [], Size.zero, const {}, const {});
  final horizontal = direction.isHorizontal;
  double crossOf(Size s) => horizontal ? s.height : s.width;
  double rankOf(Size s) => horizontal ? s.width : s.height;

  // 1. Break cycles with a DFS; back edges are reversed for ranking.
  final outEdges = List.generate(n, (_) => <int>[]);
  for (var i = 0; i < edges.length; i++) {
    outEdges[edges[i].u].add(i);
  }
  final reversed = List<bool>.filled(edges.length, false);
  final state = List<int>.filled(n, 0);
  for (var s = 0; s < n; s++) {
    if (state[s] != 0) continue;
    final stack = <(int, int)>[(s, 0)];
    state[s] = 1;
    while (stack.isNotEmpty) {
      final (v, next) = stack.last;
      if (next >= outEdges[v].length) {
        state[v] = 2;
        stack.removeLast();
        continue;
      }
      stack[stack.length - 1] = (v, next + 1);
      final e = outEdges[v][next];
      final w = edges[e].v;
      if (state[w] == 1) {
        reversed[e] = true;
      } else if (state[w] == 0) {
        state[w] = 1;
        stack.add((w, 0));
      }
    }
  }
  (int, int) dag(int e) =>
      reversed[e] ? (edges[e].v, edges[e].u) : (edges[e].u, edges[e].v);

  // 2. Longest-path ranking, then pull sources next to their successors.
  final succ = List.generate(n, (_) => <int>[]);
  final indeg = List<int>.filled(n, 0);
  for (var e = 0; e < edges.length; e++) {
    final (a, b) = dag(e);
    succ[a].add(b);
    indeg[b]++;
  }
  final rank = List<int>.filled(n, 0);
  final remaining = List<int>.of(indeg);
  final queue = <int>[
    for (var v = 0; v < n; v++)
      if (indeg[v] == 0) v,
  ];
  final topo = <int>[];
  for (var qi = 0; qi < queue.length; qi++) {
    final v = queue[qi];
    topo.add(v);
    for (final w in succ[v]) {
      rank[w] = math.max(rank[w], rank[v] + 1);
      if (--remaining[w] == 0) queue.add(w);
    }
  }
  for (final v in topo.reversed) {
    if (indeg[v] == 0 && succ[v].isNotEmpty) {
      rank[v] = succ[v].map((w) => rank[w]).reduce(math.min) - 1;
    }
  }

  // 3. Vertices (items + dummies) and unit-span segments.
  final vRank = List<int>.of(rank);
  final vCross = [for (final s in sizes) crossOf(s)];
  final vRankSize = [for (final s in sizes) rankOf(s)];
  final isDummy = List<bool>.filled(n, false, growable: true);
  final preds = List.generate(n, (_) => <int>[], growable: true);
  final succs = List.generate(n, (_) => <int>[], growable: true);
  final chains = <int, List<int>>{};
  final labelDummy = <int, int>{};
  var maxRank = rank.fold<int>(0, math.max);
  final gapLabel = List<double>.filled(maxRank + 1, 0);
  for (var e = 0; e < edges.length; e++) {
    final (a, b) = dag(e);
    final span = vRank[b] - vRank[a];
    final label = edges[e].label;
    final chain = [a];
    for (var r = vRank[a] + 1; r < vRank[b]; r++) {
      final labelled = label != null && r == vRank[a] + span ~/ 2;
      vRank.add(r);
      vCross.add(labelled ? crossOf(label) + 8 : 6);
      vRankSize.add(labelled ? rankOf(label) : 0);
      isDummy.add(true);
      preds.add([]);
      succs.add([]);
      if (labelled) labelDummy[e] = vRank.length - 1;
      chain.add(vRank.length - 1);
    }
    chain.add(b);
    if (label != null && span == 1) {
      gapLabel[vRank[a]] = math.max(gapLabel[vRank[a]], rankOf(label));
    }
    for (var i = 0; i + 1 < chain.length; i++) {
      succs[chain[i]].add(chain[i + 1]);
      preds[chain[i + 1]].add(chain[i]);
    }
    chains[e] = chain;
  }
  final vCount = vRank.length;
  maxRank = vRank.fold<int>(0, math.max);

  // 4. Order vertices within layers (barycentric sweeps, keep the best).
  var layers = List.generate(maxRank + 1, (_) => <int>[]);
  for (var v = 0; v < vCount; v++) {
    layers[vRank[v]].add(v);
  }
  final pos = List<int>.filled(vCount, 0);
  void index(List<List<int>> ls) {
    for (final layer in ls) {
      for (var i = 0; i < layer.length; i++) {
        pos[layer[i]] = i;
      }
    }
  }

  int crossings(List<List<int>> ls) {
    var total = 0;
    for (var r = 0; r < ls.length - 1; r++) {
      final segs = <(int, int)>[];
      for (final v in ls[r]) {
        for (final w in succs[v]) {
          segs.add((pos[v], pos[w]));
        }
      }
      for (var i = 0; i < segs.length; i++) {
        for (var j = i + 1; j < segs.length; j++) {
          if ((segs[i].$1 - segs[j].$1) * (segs[i].$2 - segs[j].$2) < 0) {
            total++;
          }
        }
      }
    }
    return total;
  }

  void reorder(List<int> layer, List<List<int>> neighbours) {
    final keyed =
        [
          for (var i = 0; i < layer.length; i++)
            (
              layer[i],
              neighbours[layer[i]].isEmpty
                  ? i.toDouble()
                  : neighbours[layer[i]]
                            .map((w) => pos[w])
                            .reduce((a, b) => a + b) /
                        neighbours[layer[i]].length,
              i,
            ),
        ]..sort((a, b) {
          final c = a.$2.compareTo(b.$2);
          return c != 0 ? c : a.$3.compareTo(b.$3);
        });
    for (var i = 0; i < keyed.length; i++) {
      layer[i] = keyed[i].$1;
      pos[layer[i]] = i;
    }
  }

  index(layers);
  var best = [for (final l in layers) List<int>.of(l)];
  var bestCrossings = crossings(layers);
  for (var iter = 0; iter < 12 && bestCrossings > 0; iter++) {
    if (iter.isEven) {
      for (var r = 1; r <= maxRank; r++) {
        reorder(layers[r], preds);
      }
    } else {
      for (var r = maxRank - 1; r >= 0; r--) {
        reorder(layers[r], succs);
      }
    }
    final c = crossings(layers);
    if (c < bestCrossings) {
      bestCrossings = c;
      best = [for (final l in layers) List<int>.of(l)];
    }
  }
  layers = best;
  index(layers);

  // 5. Cross-axis coordinates: pack, then align with neighbours.
  final x = List<double>.filled(vCount, 0);
  double sep(int a, int b) =>
      vCross[a] / 2 +
      vCross[b] / 2 +
      (isDummy[a] || isDummy[b] ? _dummyGap : _itemGap);
  for (final layer in layers) {
    var cursor = 0.0;
    for (var i = 0; i < layer.length; i++) {
      if (i > 0) cursor += sep(layer[i - 1], layer[i]);
      x[layer[i]] = cursor;
    }
    final shift = cursor / 2;
    for (final v in layer) {
      x[v] -= shift;
    }
  }
  void resolve(List<int> layer, List<double> desired) {
    final m = layer.length;
    if (m == 0) return;
    final fwd = List<double>.filled(m, 0);
    final bwd = List<double>.filled(m, 0);
    fwd[0] = desired[0];
    for (var i = 1; i < m; i++) {
      fwd[i] = math.max(desired[i], fwd[i - 1] + sep(layer[i - 1], layer[i]));
    }
    bwd[m - 1] = desired[m - 1];
    for (var i = m - 2; i >= 0; i--) {
      bwd[i] = math.min(desired[i], bwd[i + 1] - sep(layer[i], layer[i + 1]));
    }
    for (var i = 0; i < m; i++) {
      x[layer[i]] = (fwd[i] + bwd[i]) / 2;
    }
  }

  void align(List<int> layer, List<List<int>> neighbours) {
    resolve(layer, [
      for (final v in layer)
        neighbours[v].isEmpty
            ? x[v]
            : neighbours[v].map((w) => x[w]).reduce((a, b) => a + b) /
                  neighbours[v].length,
    ]);
  }

  for (var iter = 0; iter < 6; iter++) {
    for (var r = 1; r <= maxRank; r++) {
      align(layers[r], preds);
    }
    for (var r = maxRank - 1; r >= 0; r--) {
      align(layers[r], succs);
    }
  }
  var minCross = double.infinity;
  var maxCross = double.negativeInfinity;
  for (var v = 0; v < vCount; v++) {
    minCross = math.min(minCross, x[v] - vCross[v] / 2);
    maxCross = math.max(maxCross, x[v] + vCross[v] / 2);
  }
  for (var v = 0; v < vCount; v++) {
    x[v] -= minCross;
  }
  final crossExtent = maxCross - minCross;

  // 6. Rank-axis coordinates.
  final thickness = List<double>.filled(maxRank + 1, 0);
  for (var v = 0; v < vCount; v++) {
    thickness[vRank[v]] = math.max(thickness[vRank[v]], vRankSize[v]);
  }
  final rankCenter = List<double>.filled(maxRank + 1, 0);
  var cursor = 0.0;
  for (var r = 0; r <= maxRank; r++) {
    rankCenter[r] = cursor + thickness[r] / 2;
    cursor += thickness[r];
    if (r < maxRank) {
      cursor += _rankGap + (r < gapLabel.length ? gapLabel[r] : 0);
    }
  }
  final rankExtent = cursor;

  Offset place(int v) {
    final c = x[v];
    final r = rankCenter[vRank[v]];
    return switch (direction) {
      MermaidDirection.topDown => Offset(c, r),
      MermaidDirection.bottomUp => Offset(c, rankExtent - r),
      MermaidDirection.leftRight => Offset(r, c),
      MermaidDirection.rightLeft => Offset(rankExtent - r, c),
    };
  }

  final waypoints = <int, List<Offset>>{};
  final labelAnchors = <int, Offset>{};
  for (var e = 0; e < edges.length; e++) {
    final chain = chains[e]!;
    var points = [for (final v in chain.sublist(1, chain.length - 1)) place(v)];
    if (reversed[e]) points = points.reversed.toList();
    waypoints[edges[e].index] = points;
    final ld = labelDummy[e];
    if (ld != null) labelAnchors[edges[e].index] = place(ld);
  }
  return _LevelLayout(
    [for (var v = 0; v < n; v++) place(v)],
    horizontal ? Size(rankExtent, crossExtent) : Size(crossExtent, rankExtent),
    waypoints,
    labelAnchors,
  );
}

// ---------------------------------------------------------------------------
// Flowchart
// ---------------------------------------------------------------------------

class _NodeBox {
  _NodeBox(
    this.node,
    this.text,
    this.size,
    this.fill,
    this.stroke,
    this.width,
    this.dashed,
  );

  final FlowNode node;
  final TextPainter text;
  final Size size;
  final Color fill;
  final Color stroke;
  final double width;
  final bool dashed;
  Offset center = Offset.zero;
}

class _ClusterLayout {
  _ClusterLayout(
    this.children,
    this.level,
    this.size,
    this.contentOffset,
    this.title,
  );

  final List<String> children;
  final _LevelLayout level;
  final Size size;
  final Offset contentOffset;
  final TextPainter? title;
}

class _FlowchartLayout {
  _FlowchartLayout(this.d, this.t);

  final FlowchartDiagram d;
  final MermaidTheme t;

  final boxes = <String, _NodeBox>{};
  final clusterAccent = <String, Color>{};
  final childrenOf = <String?, List<String>>{};
  final levelEdges = <String?, List<(String, String, int)>>{};
  final clusterLayouts = <String, _ClusterLayout>{};
  final edgeLabels = <int, TextPainter>{};
  final waypoints = <int, List<Offset>>{};
  final labelAnchors = <int, Offset>{};
  final clusterRects = <(String, Rect, int)>[];

  List<String?> _chain(String? subgraph) {
    final out = <String?>[];
    var current = subgraph;
    while (current != null && d.subgraphs.containsKey(current)) {
      out.add(current);
      current = d.subgraphs[current]!.parent;
    }
    out.add(null);
    return out;
  }

  MermaidScene build() {
    var i = 1;
    for (final id in d.subgraphs.keys) {
      clusterAccent[id] = t.accent(i++);
    }
    for (final node in d.nodes.values) {
      boxes[node.id] = _measure(node);
      // Register the node and its cluster ancestry in declaration order.
      final chain = _chain(node.subgraph);
      childrenOf.putIfAbsent(chain.first, () => []).add('n:${node.id}');
      for (var c = 0; c < chain.length - 1; c++) {
        final key = 'c:${chain[c]}';
        final siblings = childrenOf.putIfAbsent(chain[c + 1], () => []);
        if (!siblings.contains(key)) siblings.add(key);
      }
    }
    for (var e = 0; e < d.edges.length; e++) {
      final edge = d.edges[e];
      if (edge.label != null && edge.line != FlowEdgeLine.invisible) {
        edgeLabels[e] = t.label(
          edge.label!,
          color: d.edgeStyleOf(e).color ?? t.text,
          fontSize: 12,
          weight: FontWeight.w400,
          maxWidth: 150,
        );
      }
      if (edge.from == edge.to) continue;
      final a = boxes[edge.from]!.node;
      final b = boxes[edge.to]!.node;
      final chainA = _chain(a.subgraph);
      final chainB = _chain(b.subgraph).toSet();
      final lca = chainA.firstWhere(chainB.contains);
      levelEdges.putIfAbsent(lca, () => []).add((
        _itemUnder(a, lca),
        _itemUnder(b, lca),
        e,
      ));
    }

    final root = _layoutLevel(null, d.direction);
    final ops = <MermaidOp>[];
    _place(null, root, Offset.zero, 0);

    // Clusters (outer first), edges, edge labels, nodes.
    for (final (id, rect, _) in clusterRects) {
      _paintCluster(ops, id, rect);
    }
    final labelOps = <MermaidOp>[];
    for (var e = 0; e < d.edges.length; e++) {
      _paintEdge(ops, labelOps, e);
    }
    ops.addAll(labelOps);
    for (final box in boxes.values) {
      _paintNode(ops, box);
    }
    return MermaidScene(
      ops,
      labels: [
        for (final b in boxes.values) b.node.label,
        for (final e in d.edges)
          if (e.label != null) e.label!,
      ],
    );
  }

  String _itemUnder(FlowNode node, String? level) {
    if (node.subgraph == level ||
        (node.subgraph != null && !d.subgraphs.containsKey(node.subgraph))) {
      return 'n:${node.id}';
    }
    var current = node.subgraph;
    while (current != null) {
      final parent = d.subgraphs[current]?.parent;
      if (parent == level) return 'c:$current';
      current = parent;
    }
    return 'n:${node.id}';
  }

  _ClusterLayout _layoutLevel(String? id, MermaidDirection inherited) {
    final direction = id == null
        ? inherited
        : d.subgraphs[id]!.direction ?? inherited;
    final children = childrenOf[id] ?? const <String>[];
    final sizes = <Size>[];
    for (final key in children) {
      if (key.startsWith('n:')) {
        sizes.add(boxes[key.substring(2)]!.size);
      } else {
        final childId = key.substring(2);
        final child = _layoutLevel(childId, direction);
        clusterLayouts[childId] = child;
        sizes.add(child.size);
      }
    }
    final indexOf = {for (var i = 0; i < children.length; i++) children[i]: i};
    final level = _layered(sizes, [
      for (final (a, b, e) in levelEdges[id] ?? const <(String, String, int)>[])
        if (indexOf.containsKey(a) && indexOf.containsKey(b))
          _LevelEdge(
            indexOf[a]!,
            indexOf[b]!,
            e,
            edgeLabels[e] == null
                ? null
                : Size(edgeLabels[e]!.width + 12, edgeLabels[e]!.height + 8),
          ),
    ], direction);
    if (id == null) {
      return _ClusterLayout(children, level, level.size, Offset.zero, null);
    }
    final sg = d.subgraphs[id]!;
    final style = d.clusterStyleOf(id);
    final title = sg.title.isEmpty
        ? null
        : t.label(
            sg.title,
            color: style.color ?? clusterAccent[id]!,
            fontSize: 12.5,
            weight: FontWeight.w700,
            maxWidth: 220,
          );
    const pad = 14.0;
    final titleH = title == null ? 0.0 : title.height + 8;
    final innerW = math.max(level.size.width, title?.width ?? 0);
    final size = Size(innerW + pad * 2, level.size.height + titleH + pad * 2);
    return _ClusterLayout(
      children,
      level,
      size,
      Offset(pad + (innerW - level.size.width) / 2, pad + titleH),
      title,
    );
  }

  void _place(String? id, _ClusterLayout layout, Offset topLeft, int depth) {
    final origin = topLeft + layout.contentOffset;
    if (id != null) {
      clusterRects.add((id, topLeft & layout.size, depth));
    }
    for (final entry in layout.level.waypoints.entries) {
      waypoints[entry.key] = [for (final p in entry.value) p + origin];
    }
    for (final entry in layout.level.labelAnchors.entries) {
      labelAnchors[entry.key] = entry.value + origin;
    }
    for (var i = 0; i < layout.children.length; i++) {
      final key = layout.children[i];
      final center = layout.level.centers[i] + origin;
      if (key.startsWith('n:')) {
        boxes[key.substring(2)]!.center = center;
      } else {
        final childId = key.substring(2);
        final child = clusterLayouts[childId]!;
        _place(
          childId,
          child,
          center - Offset(child.size.width / 2, child.size.height / 2),
          depth + 1,
        );
      }
    }
  }

  _NodeBox _measure(FlowNode node) {
    final style = d.styleOf(node);
    final accent = switch (node.shape) {
      MermaidNodeShape.rhombus => t.accent(3),
      MermaidNodeShape.cylinder => t.accent(6),
      MermaidNodeShape.circle || MermaidNodeShape.doubleCircle => t.accent(2),
      _ =>
        node.subgraph != null && clusterAccent.containsKey(node.subgraph)
            ? clusterAccent[node.subgraph]!
            : t.accent(0),
    };
    final fill = style.fill ?? t.tint(accent, 1.15);
    final textColor =
        style.color ?? (style.fill != null ? t.onFill(style.fill!) : t.text);
    final round =
        node.shape == MermaidNodeShape.circle ||
        node.shape == MermaidNodeShape.doubleCircle;
    final text = t.label(
      node.label,
      color: textColor,
      weight: style.bold == true ? FontWeight.w700 : FontWeight.w500,
      maxWidth: round ? 110 : 170,
    );
    final w = math.max(text.width + 26, 56.0);
    final h = math.max(text.height + 18, 38.0);
    final size = switch (node.shape) {
      MermaidNodeShape.rhombus => Size(w * 1.6 + 8, h * 1.7 + 4),
      MermaidNodeShape.circle => Size.square(math.max(w, h) + 6),
      MermaidNodeShape.doubleCircle => Size.square(math.max(w, h) + 16),
      MermaidNodeShape.hexagon ||
      MermaidNodeShape.parallelogram ||
      MermaidNodeShape.parallelogramAlt ||
      MermaidNodeShape.trapezoid ||
      MermaidNodeShape.trapezoidAlt => Size(w + h * 0.8, h),
      MermaidNodeShape.stadium => Size(w + h * 0.4, h),
      MermaidNodeShape.cylinder => Size(w, h + 14),
      MermaidNodeShape.asymmetric => Size(w + h * 0.4, h),
      MermaidNodeShape.subroutine => Size(w + 16, h),
      _ => Size(w, h),
    };
    return _NodeBox(
      node,
      text,
      size,
      fill,
      style.stroke ?? accent,
      style.strokeWidth ?? 1.6,
      style.dashed ?? false,
    );
  }

  void _paintCluster(List<MermaidOp> ops, String id, Rect rect) {
    final style = d.clusterStyleOf(id);
    final accent = clusterAccent[id]!;
    ops.add(
      MermaidPathOp(
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
        fill: style.fill ?? accent.withValues(alpha: t.dark ? 0.10 : 0.06),
        stroke: style.stroke ?? accent.withValues(alpha: 0.6),
        strokeWidth: style.strokeWidth ?? 1.2,
        dashed: style.dashed ?? false,
      ),
    );
    final title = clusterLayouts[id]?.title;
    if (title != null) {
      ops.add(
        MermaidTextOp(
          title,
          Offset(rect.center.dx - title.width / 2, rect.top + 10),
        ),
      );
    }
  }

  Offset _clip(_NodeBox box, Offset toward) {
    final c = box.center;
    final dx = toward.dx - c.dx;
    final dy = toward.dy - c.dy;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return c;
    final hw = box.size.width / 2;
    final hh = box.size.height / 2;
    double t;
    switch (box.node.shape) {
      case MermaidNodeShape.rhombus:
        t = 1 / (dx.abs() / hw + dy.abs() / hh);
      case MermaidNodeShape.circle || MermaidNodeShape.doubleCircle:
        t = 1 / math.sqrt((dx / hw) * (dx / hw) + (dy / hh) * (dy / hh));
      default:
        t = math.min(
          dx.abs() < 1e-6 ? double.infinity : hw / dx.abs(),
          dy.abs() < 1e-6 ? double.infinity : hh / dy.abs(),
        );
    }
    t = math.min(t, 1);
    return c + Offset(dx * t, dy * t);
  }

  void _paintEdge(List<MermaidOp> ops, List<MermaidOp> labelOps, int e) {
    final edge = d.edges[e];
    if (edge.line == FlowEdgeLine.invisible) return;
    final style = d.edgeStyleOf(e);
    final color = style.stroke ?? t.edge;
    final width =
        style.strokeWidth ?? (edge.line == FlowEdgeLine.thick ? 3.0 : 1.5);
    final dashed = style.dashed ?? edge.line == FlowEdgeLine.dotted;
    final a = boxes[edge.from]!;
    final b = boxes[edge.to]!;

    if (edge.from == edge.to) {
      final r = Rect.fromCenter(
        center: a.center,
        width: a.size.width,
        height: a.size.height,
      );
      final start = Offset(r.right, r.center.dy - r.height / 4);
      final end = Offset(r.right + 2, r.center.dy + r.height / 4);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          r.right + 36,
          r.top - 6,
          r.right + 36,
          r.bottom + 6,
          end.dx + 6,
          end.dy,
        );
      ops.add(
        MermaidPathOp(path, stroke: color, strokeWidth: width, dashed: dashed),
      );
      _addMarker(
        ops,
        edge.endMarker,
        end,
        const Offset(-1, 0),
        color,
        width,
        t.surface,
      );
      final label = edgeLabels[e];
      if (label != null) {
        _addLabelBox(
          labelOps,
          label,
          Offset(r.right + 34 + label.width / 2, r.center.dy),
          background: t.surface.withValues(alpha: 0.94),
        );
      }
      return;
    }

    final mids = waypoints[e] ?? const <Offset>[];
    final start = _clip(a, mids.isEmpty ? b.center : mids.first);
    var end = _clip(b, mids.isEmpty ? a.center : mids.last);
    final beforeEnd = mids.isEmpty ? start : mids.last;
    final afterStart = mids.isEmpty ? end : mids.first;
    final endDir = end - beforeEnd;
    final startDir = start - afterStart;
    final tip = end;
    if (edge.endMarker == FlowEdgeMarker.arrow) {
      end = end - _unit(endDir) * (6 + width);
    }
    var origin = start;
    if (edge.startMarker == FlowEdgeMarker.arrow) {
      origin = start - _unit(startDir) * (6 + width);
    }
    final points = [origin, ...mids, end];
    ops.add(
      MermaidPathOp(
        _smoothPath(points),
        stroke: color,
        strokeWidth: width,
        dashed: dashed,
      ),
    );
    _addMarker(ops, edge.endMarker, tip, endDir, color, width, t.surface);
    _addMarker(ops, edge.startMarker, start, startDir, color, width, t.surface);

    final label = edgeLabels[e];
    if (label != null) {
      final anchor =
          labelAnchors[e] ??
          (mids.isEmpty
              ? Offset.lerp(start, tip, 0.5)!
              : mids[mids.length ~/ 2]);
      _addLabelBox(
        labelOps,
        label,
        anchor,
        background: t.surface.withValues(alpha: 0.94),
        border: color.withValues(alpha: 0.35),
      );
    }
  }

  void _paintNode(List<MermaidOp> ops, _NodeBox box) {
    final r = Rect.fromCenter(
      center: box.center,
      width: box.size.width,
      height: box.size.height,
    );
    final h = r.height;
    Path? extra;
    final Path path;
    switch (box.node.shape) {
      case MermaidNodeShape.rect:
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)));
      case MermaidNodeShape.round:
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(14)));
      case MermaidNodeShape.stadium:
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(h / 2)));
      case MermaidNodeShape.subroutine:
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)));
        extra = Path()
          ..moveTo(r.left + 8, r.top)
          ..lineTo(r.left + 8, r.bottom)
          ..moveTo(r.right - 8, r.top)
          ..lineTo(r.right - 8, r.bottom);
      case MermaidNodeShape.cylinder:
        const ry = 7.0;
        final radius = Radius.elliptical(r.width / 2, ry);
        path = Path()
          ..moveTo(r.left, r.top + ry)
          ..lineTo(r.left, r.bottom - ry)
          ..arcToPoint(
            Offset(r.right, r.bottom - ry),
            radius: radius,
            clockwise: false,
          )
          ..lineTo(r.right, r.top + ry)
          ..arcToPoint(
            Offset(r.left, r.top + ry),
            radius: radius,
            clockwise: false,
          )
          ..close();
        extra = Path()
          ..moveTo(r.left, r.top + ry)
          ..arcToPoint(
            Offset(r.right, r.top + ry),
            radius: radius,
            clockwise: false,
          );
      case MermaidNodeShape.circle:
        path = Path()..addOval(r);
      case MermaidNodeShape.doubleCircle:
        path = Path()..addOval(r);
        extra = Path()..addOval(r.deflate(4));
      case MermaidNodeShape.asymmetric:
        path = _polygon([
          r.topLeft,
          r.topRight,
          r.bottomRight,
          r.bottomLeft,
          Offset(r.left + h * 0.35, r.center.dy),
        ]);
      case MermaidNodeShape.rhombus:
        path = _polygon([
          r.topCenter,
          r.centerRight,
          r.bottomCenter,
          r.centerLeft,
        ]);
      case MermaidNodeShape.hexagon:
        final inset = h * 0.4;
        path = _polygon([
          Offset(r.left + inset, r.top),
          Offset(r.right - inset, r.top),
          r.centerRight,
          Offset(r.right - inset, r.bottom),
          Offset(r.left + inset, r.bottom),
          r.centerLeft,
        ]);
      case MermaidNodeShape.parallelogram:
        final s = h * 0.4;
        path = _polygon([
          Offset(r.left + s, r.top),
          r.topRight,
          Offset(r.right - s, r.bottom),
          r.bottomLeft,
        ]);
      case MermaidNodeShape.parallelogramAlt:
        final s = h * 0.4;
        path = _polygon([
          r.topLeft,
          Offset(r.right - s, r.top),
          r.bottomRight,
          Offset(r.left + s, r.bottom),
        ]);
      case MermaidNodeShape.trapezoid:
        final s = h * 0.4;
        path = _polygon([
          Offset(r.left + s, r.top),
          Offset(r.right - s, r.top),
          r.bottomRight,
          r.bottomLeft,
        ]);
      case MermaidNodeShape.trapezoidAlt:
        final s = h * 0.4;
        path = _polygon([
          r.topLeft,
          r.topRight,
          Offset(r.right - s, r.bottom),
          Offset(r.left + s, r.bottom),
        ]);
    }
    ops.add(
      MermaidPathOp(
        path,
        fill: box.fill,
        stroke: box.stroke,
        strokeWidth: box.width,
        dashed: box.dashed,
      ),
    );
    if (extra != null) {
      ops.add(MermaidPathOp(extra, stroke: box.stroke, strokeWidth: box.width));
    }
    var textCenter = box.center;
    if (box.node.shape == MermaidNodeShape.asymmetric) {
      textCenter += Offset(h * 0.15, 0);
    } else if (box.node.shape == MermaidNodeShape.cylinder) {
      textCenter += const Offset(0, 4);
    }
    ops.add(
      MermaidTextOp(
        box.text,
        textCenter - Offset(box.text.width / 2, box.text.height / 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sequence diagram
// ---------------------------------------------------------------------------

class _OpenBlock {
  _OpenBlock(this.start, this.top);

  final SequenceBlockStart start;
  final double top;
  double left = double.infinity;
  double right = double.negativeInfinity;
  final dividers = <(double, String)>[];
}

MermaidScene _buildSequence(SequenceDiagram d, MermaidTheme t) {
  final ps = d.participants;
  final n = ps.length;
  final idx = {for (var i = 0; i < n; i++) ps[i].id: i};
  final headers = [
    for (final p in ps)
      t.label(p.label, color: t.text, weight: FontWeight.w600, maxWidth: 160),
  ];
  final boxW = [for (final h in headers) math.max(h.width + 28, 96.0)];
  final boxH = headers.map((h) => h.height + 18).fold<double>(0, math.max);
  final hasActor = ps.any((p) => p.isActor);
  final headerH = boxH + (hasActor ? 34 : 0);

  // Measure event text.
  final texts = <SequenceEvent, TextPainter>{};
  for (final event in d.events) {
    switch (event) {
      case SequenceMessage():
        if (event.text.isNotEmpty) {
          texts[event] = t.label(
            event.text,
            color: t.text,
            fontSize: 12.5,
            weight: FontWeight.w400,
            maxWidth: 220,
          );
        }
      case SequenceNote():
        texts[event] = t.label(
          event.text,
          color: t.text,
          fontSize: 12.5,
          weight: FontWeight.w400,
          maxWidth: 200,
        );
      default:
        break;
    }
  }

  // Horizontal spacing constraints between participant centres.
  final constraints = <(int, int, double)>[
    for (var i = 0; i + 1 < n; i++)
      (i, i + 1, boxW[i] / 2 + boxW[i + 1] / 2 + 28),
  ];
  for (final event in d.events) {
    final text = texts[event];
    switch (event) {
      case SequenceMessage():
        final a = idx[event.from]!;
        final b = idx[event.to]!;
        final w = (text?.width ?? 0) + (event.number != null ? 24 : 0);
        if (a == b) {
          if (a + 1 < n) constraints.add((a, a + 1, w + 52));
        } else {
          constraints.add((math.min(a, b), math.max(a, b), w + 40));
        }
      case SequenceNote():
        final w = text!.width + 20;
        final i = idx[event.participants.first]!;
        if (event.placement == SequenceNotePlacement.leftOf && i > 0) {
          constraints.add((i - 1, i, w + 20));
        } else if (event.placement == SequenceNotePlacement.rightOf &&
            i + 1 < n) {
          constraints.add((i, i + 1, w + 20));
        }
      default:
        break;
    }
  }
  constraints.sort((a, b) => (a.$2 - a.$1).compareTo(b.$2 - b.$1));
  final gaps = List<double>.filled(math.max(n - 1, 0), 0);
  for (final (a, b, dist) in constraints) {
    var current = 0.0;
    for (var k = a; k < b; k++) {
      current += gaps[k];
    }
    if (current < dist) {
      final add = (dist - current) / (b - a);
      for (var k = a; k < b; k++) {
        gaps[k] += add;
      }
    }
  }
  final x = List<double>.filled(n, 0);
  for (var i = 1; i < n; i++) {
    x[i] = x[i - 1] + gaps[i - 1];
  }

  final background = <MermaidOp>[];
  final frames = <MermaidOp>[];
  final lines = <MermaidOp>[];
  final notes = <MermaidOp>[];
  final top = <MermaidOp>[];
  final labels = [for (final p in ps) p.label];
  final stack = <_OpenBlock>[];

  void touch(double left, double right) {
    for (final block in stack) {
      block.left = math.min(block.left, left);
      block.right = math.max(block.right, right);
    }
  }

  var y = headerH + 22;
  for (final event in d.events) {
    switch (event) {
      case SequenceMessage():
        final a = idx[event.from]!;
        final b = idx[event.to]!;
        final text = texts[event];
        if (text != null) labels.add(event.text);
        final color = t.edge;
        if (a != b) {
          final dir = b > a ? 1.0 : -1.0;
          if (text != null) {
            top.add(
              MermaidTextOp(
                text,
                Offset((x[a] + x[b]) / 2 - text.width / 2, y),
              ),
            );
            y += text.height + 4;
          }
          final tipEnd = Offset(x[b] - dir * 2, y);
          final head =
              event.arrow == SequenceArrow.arrow ||
              event.arrow == SequenceArrow.bidirectional;
          final lineEnd = head ? tipEnd - Offset(dir * 8, 0) : tipEnd;
          var lineStart = Offset(x[a] + dir * 2, y);
          if (event.arrow == SequenceArrow.bidirectional) {
            lineStart += Offset(dir * 8, 0);
          }
          lines.add(
            MermaidPathOp(
              Path()
                ..moveTo(lineStart.dx, lineStart.dy)
                ..lineTo(lineEnd.dx, lineEnd.dy),
              stroke: color,
              strokeWidth: 1.5,
              dashed: event.dotted,
            ),
          );
          _sequenceHead(lines, event.arrow, tipEnd, Offset(dir, 0), color, t);
          if (event.arrow == SequenceArrow.bidirectional) {
            _sequenceHead(
              lines,
              SequenceArrow.arrow,
              Offset(x[a] + dir * 2, y),
              Offset(-dir, 0),
              color,
              t,
            );
          }
          if (event.number != null) {
            _badge(top, '${event.number}', Offset(x[a], y), t);
          }
          touch(math.min(x[a], x[b]) - 56, math.max(x[a], x[b]) + 56);
          y += 22;
        } else {
          y += 4;
          final loopTop = y;
          final loopBottom = y + math.max(22.0, (text?.height ?? 0) + 6);
          final path = Path()
            ..moveTo(x[a] + 2, loopTop)
            ..lineTo(x[a] + 34, loopTop)
            ..lineTo(x[a] + 34, loopBottom)
            ..lineTo(x[a] + 10, loopBottom);
          lines.add(
            MermaidPathOp(
              path,
              stroke: color,
              strokeWidth: 1.5,
              dashed: event.dotted,
            ),
          );
          _sequenceHead(
            lines,
            event.arrow,
            Offset(x[a] + 2, loopBottom),
            const Offset(-1, 0),
            color,
            t,
          );
          if (text != null) {
            top.add(MermaidTextOp(text, Offset(x[a] + 42, loopTop + 2)));
          }
          if (event.number != null) {
            _badge(top, '${event.number}', Offset(x[a], loopTop), t);
          }
          touch(x[a] - 56, x[a] + 50 + (text?.width ?? 0));
          y = loopBottom + 18;
        }
      case SequenceNote():
        final text = texts[event]!;
        labels.add(event.text);
        final ids = [for (final id in event.participants) idx[id]!];
        final w = text.width + 20;
        final h = text.height + 12;
        final double left;
        final double width;
        switch (event.placement) {
          case SequenceNotePlacement.leftOf:
            left = x[ids.first] - 12 - w;
            width = w;
          case SequenceNotePlacement.rightOf:
            left = x[ids.first] + 12;
            width = w;
          case SequenceNotePlacement.over:
            final lo = ids.map((i) => x[i]).reduce(math.min);
            final hi = ids.map((i) => x[i]).reduce(math.max);
            width = math.max(w, hi - lo + 48);
            left = (lo + hi) / 2 - width / 2;
        }
        final rect = Rect.fromLTWH(left, y, width, h);
        final accent = t.accent(3);
        notes.add(
          MermaidPathOp(
            Path()..addRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            ),
            fill: t.tint(accent, 1.5),
            stroke: accent,
            strokeWidth: 1.2,
          ),
        );
        notes.add(
          MermaidTextOp(
            text,
            rect.center - Offset(text.width / 2, text.height / 2),
          ),
        );
        touch(rect.left - 12, rect.right + 12);
        y += h + 14;
      case SequenceBlockStart():
        stack.add(_OpenBlock(event, y));
        if (event.label.isNotEmpty) labels.add(event.label);
        y += event.kind == SequenceBlockKind.rect ? 10 : 34;
      case SequenceBlockDivider():
        if (stack.isNotEmpty) {
          stack.last.dividers.add((y, event.label));
          y += 30;
        }
      case SequenceBlockEnd():
        if (stack.isEmpty) break;
        final block = stack.removeLast();
        if (block.left == double.infinity) {
          block.left = x.first - 56;
          block.right = x.last + 56;
        }
        if (stack.isNotEmpty) {
          stack.last.left = math.min(stack.last.left, block.left - 8);
          stack.last.right = math.max(stack.last.right, block.right + 8);
        }
        final rect = Rect.fromLTRB(block.left, block.top, block.right, y + 2);
        _paintBlock(
          block.start.kind == SequenceBlockKind.rect ? background : frames,
          block,
          rect,
          t,
        );
        y += 12;
    }
  }
  final footerTop = y + 8;

  for (var i = 0; i < n; i++) {
    final accent = t.accent(i);
    lines.insert(
      0,
      MermaidPathOp(
        Path()
          ..moveTo(x[i], headerH)
          ..lineTo(x[i], footerTop),
        stroke: accent.withValues(alpha: 0.55),
        strokeWidth: 1.2,
        dashed: true,
      ),
    );
    for (final boxTop in [0.0, footerTop]) {
      _participant(
        top,
        ps[i],
        headers[i],
        x[i],
        boxTop,
        boxW[i],
        boxH,
        headerH,
        accent,
        t,
      );
    }
  }
  return MermaidScene([
    ...background,
    ...lines,
    ...frames,
    ...notes,
    ...top,
  ], labels: labels);
}

void _sequenceHead(
  List<MermaidOp> ops,
  SequenceArrow arrow,
  Offset tip,
  Offset dir,
  Color color,
  MermaidTheme t,
) {
  switch (arrow) {
    case SequenceArrow.arrow || SequenceArrow.bidirectional:
      _addMarker(ops, FlowEdgeMarker.arrow, tip, dir, color, 1.5, t.surface);
    case SequenceArrow.cross:
      _addMarker(ops, FlowEdgeMarker.cross, tip, dir, color, 1.5, t.surface);
    case SequenceArrow.async:
      final u = _unit(dir);
      final nrm = Offset(-u.dy, u.dx);
      final base = tip - u * 9;
      ops.add(
        MermaidPathOp(
          Path()
            ..moveTo((base + nrm * 5).dx, (base + nrm * 5).dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo((base - nrm * 5).dx, (base - nrm * 5).dy),
          stroke: color,
          strokeWidth: 1.5,
        ),
      );
    case SequenceArrow.open:
      break;
  }
}

void _badge(List<MermaidOp> ops, String text, Offset center, MermaidTheme t) {
  final accent = t.accent(0);
  ops.add(
    MermaidPathOp(
      Path()..addOval(Rect.fromCircle(center: center, radius: 9)),
      fill: accent,
    ),
  );
  final painter = t.label(
    text,
    color: t.onFill(accent),
    fontSize: 10,
    weight: FontWeight.w700,
  );
  ops.add(
    MermaidTextOp(
      painter,
      center - Offset(painter.width / 2, painter.height / 2),
    ),
  );
}

void _paintBlock(
  List<MermaidOp> ops,
  _OpenBlock block,
  Rect rect,
  MermaidTheme t,
) {
  final kind = block.start.kind;
  if (kind == SequenceBlockKind.rect) {
    final color = block.start.color ?? t.accent(1);
    final maxAlpha = t.dark ? 0.22 : 0.45;
    ops.add(
      MermaidPathOp(
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))),
        fill: color.withValues(alpha: math.min(color.a, maxAlpha)),
      ),
    );
    return;
  }
  final accent = switch (kind) {
    SequenceBlockKind.loop => t.accent(1),
    SequenceBlockKind.alt => t.accent(5),
    SequenceBlockKind.opt => t.accent(2),
    SequenceBlockKind.par => t.accent(3),
    SequenceBlockKind.critical => t.accent(4),
    SequenceBlockKind.breakBlock => t.accent(7),
    SequenceBlockKind.rect => t.accent(1),
  };
  ops.add(
    MermaidPathOp(
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))),
      fill: accent.withValues(alpha: 0.05),
      stroke: accent.withValues(alpha: 0.75),
      strokeWidth: 1.2,
    ),
  );
  final keyword = switch (kind) {
    SequenceBlockKind.breakBlock => 'break',
    _ => kind.name,
  };
  final tab = t.label(
    keyword,
    color: t.onFill(accent),
    fontSize: 11,
    weight: FontWeight.w700,
  );
  final tabRect = Rect.fromLTWH(
    rect.left,
    rect.top,
    tab.width + 14,
    tab.height + 6,
  );
  ops.add(
    MermaidPathOp(
      Path()..addRRect(
        RRect.fromRectAndCorners(
          tabRect,
          topLeft: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        ),
      ),
      fill: accent,
    ),
  );
  ops.add(MermaidTextOp(tab, tabRect.topLeft + const Offset(7, 3)));
  if (block.start.label.isNotEmpty) {
    final cond = t.label(
      '[${block.start.label}]',
      color: t.mutedText,
      fontSize: 11.5,
      weight: FontWeight.w500,
      maxWidth: math.max(80, rect.width - tabRect.width - 16),
      align: TextAlign.left,
    );
    ops.add(MermaidTextOp(cond, Offset(tabRect.right + 8, rect.top + 3)));
  }
  for (final (dy, label) in block.dividers) {
    ops.add(
      MermaidPathOp(
        Path()
          ..moveTo(rect.left, dy)
          ..lineTo(rect.right, dy),
        stroke: accent.withValues(alpha: 0.6),
        strokeWidth: 1,
        dashed: true,
      ),
    );
    if (label.isNotEmpty) {
      final text = t.label(
        '[$label]',
        color: t.mutedText,
        fontSize: 11.5,
        weight: FontWeight.w500,
        maxWidth: math.max(80, rect.width - 16),
        align: TextAlign.left,
      );
      ops.add(MermaidTextOp(text, Offset(rect.left + 8, dy + 4)));
    }
  }
}

void _participant(
  List<MermaidOp> ops,
  SequenceParticipant p,
  TextPainter text,
  double cx,
  double top,
  double width,
  double boxH,
  double headerH,
  Color accent,
  MermaidTheme t,
) {
  if (p.isActor) {
    final headCenter = Offset(cx, top + 9);
    final figure = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: 7))
      ..moveTo(cx, top + 16)
      ..lineTo(cx, top + 27)
      ..moveTo(cx - 9, top + 20)
      ..lineTo(cx + 9, top + 20)
      ..moveTo(cx, top + 27)
      ..lineTo(cx - 7, top + 35)
      ..moveTo(cx, top + 27)
      ..lineTo(cx + 7, top + 35);
    ops.add(MermaidPathOp(figure, stroke: accent, strokeWidth: 1.8));
    ops.add(MermaidTextOp(text, Offset(cx - text.width / 2, top + 38)));
    return;
  }
  final boxTop = top + headerH - boxH;
  final rect = Rect.fromLTWH(cx - width / 2, boxTop, width, boxH);
  ops.add(
    MermaidPathOp(
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))),
      fill: t.tint(accent, 1.4),
      stroke: accent,
      strokeWidth: 1.6,
    ),
  );
  ops.add(
    MermaidTextOp(text, rect.center - Offset(text.width / 2, text.height / 2)),
  );
}

// ---------------------------------------------------------------------------
// Pie
// ---------------------------------------------------------------------------

MermaidScene _buildPie(PieDiagram d, MermaidTheme t) {
  final ops = <MermaidOp>[];
  final labels = <String>[if (d.title != null) d.title!];
  var y = 0.0;
  const radius = 92.0;
  if (d.title != null) {
    final title = t.label(
      d.title!,
      color: t.text,
      fontSize: 15,
      weight: FontWeight.w700,
      maxWidth: 360,
    );
    ops.add(MermaidTextOp(title, Offset(0, y)));
    y += title.height + 12;
  }
  final total = d.slices.fold<double>(0, (s, e) => s + math.max(e.value, 0));
  final center = Offset(radius, y + radius);
  final rect = Rect.fromCircle(center: center, radius: radius);
  var angle = -math.pi / 2;
  final legend = <(Color, TextPainter)>[];
  for (var i = 0; i < d.slices.length; i++) {
    final slice = d.slices[i];
    final color = t.accent(i);
    final share = math.max(slice.value, 0) / total;
    final sweep = share * math.pi * 2;
    if (sweep > 0) {
      final path = Path()..moveTo(center.dx, center.dy);
      if (sweep >= math.pi * 2 - 1e-6) {
        path.addOval(rect);
      } else {
        path
          ..arcTo(rect, angle, sweep, false)
          ..close();
      }
      ops.add(
        MermaidPathOp(path, fill: color, stroke: t.surface, strokeWidth: 2),
      );
      if (sweep > 0.4) {
        final mid = angle + sweep / 2;
        final pct = t.label(
          '${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%',
          color: t.onFill(color),
          fontSize: 11.5,
          weight: FontWeight.w700,
        );
        final at =
            center + Offset(math.cos(mid), math.sin(mid)) * radius * 0.64;
        ops.add(MermaidTextOp(pct, at - Offset(pct.width / 2, pct.height / 2)));
      }
    }
    angle += sweep;
    final value = slice.value == slice.value.roundToDouble()
        ? slice.value.toInt().toString()
        : slice.value.toString();
    final pctText = (share * 100).toStringAsFixed(1);
    final text = d.showData
        ? '${slice.label}  $value ($pctText%)'
        : '${slice.label}  $pctText%';
    labels.add(text);
    legend.add((
      color,
      t.label(
        text,
        color: t.text,
        fontSize: 12.5,
        weight: FontWeight.w500,
        maxWidth: 200,
        align: TextAlign.left,
      ),
    ));
  }
  final legendHeight = legend.fold<double>(
    0,
    (s, e) => s + math.max(e.$2.height, 14) + 8,
  );
  var ly = center.dy - legendHeight / 2;
  final lx = radius * 2 + 28;
  for (final (color, text) in legend) {
    final rowH = math.max(text.height, 14.0);
    ops.add(
      MermaidPathOp(
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(lx, ly + rowH / 2 - 6, 12, 12),
            const Radius.circular(3),
          ),
        ),
        fill: color,
      ),
    );
    ops.add(
      MermaidTextOp(text, Offset(lx + 20, ly + (rowH - text.height) / 2)),
    );
    ly += rowH + 8;
  }
  return MermaidScene(ops, labels: labels);
}
