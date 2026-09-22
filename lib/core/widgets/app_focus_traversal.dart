import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reading order that tolerates focus nodes awaiting their first layout.
///
/// Focus nodes can attach before their render boxes have a size. Reading-order
/// sorting reads every node's rect, so a keyboard event during that interval
/// would otherwise throw from RenderBox.size.
class AppReadingOrderTraversalPolicy extends ReadingOrderTraversalPolicy {
  static bool _hasGeometry(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return false;
    if (renderObject is RenderBox) return renderObject.hasSize;
    if (renderObject is RenderSliver) return renderObject.geometry != null;
    return true;
  }

  static bool _canMoveFrom(FocusNode node) {
    final scope = node.nearestScope;
    if (scope == null) return false;
    return _hasGeometry(scope.focusedChild ?? node);
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) => super.sortDescendants(descendants.where(_hasGeometry), currentNode);

  // Flutter requires the focused node to remain in the sorted list. If that
  // node itself has no geometry yet, keep focus until layout finishes.
  @override
  bool next(FocusNode currentNode) =>
      _canMoveFrom(currentNode) && super.next(currentNode);

  @override
  bool previous(FocusNode currentNode) =>
      _canMoveFrom(currentNode) && super.previous(currentNode);

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (!_canMoveFrom(currentNode)) return false;
    // Directional traversal reads rects directly rather than sortDescendants.
    // Wait for layout instead of handing it an incomplete geometry snapshot.
    final scope = currentNode.nearestScope;
    if (scope == null || !scope.traversalDescendants.every(_hasGeometry)) {
      return false;
    }
    return super.inDirection(currentNode, direction);
  }
}
