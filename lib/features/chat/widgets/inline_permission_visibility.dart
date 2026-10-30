import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Permission ids whose in-transcript decision card is on screen.
///
/// The sticky [PendingPermissionBar] only repeats the question when the
/// card that already asks it is scrolled out of view (or was never built),
/// so the user is asked once. Keys are `sessionId/permissionId`.
final ValueNotifier<Set<String>> visibleInlinePermissions =
    ValueNotifier<Set<String>>(const <String>{});

String inlinePermissionKey(String sessionId, String permissionId) =>
    '$sessionId/$permissionId';

final Map<String, Object> _owners = <String, Object>{};

void _setVisible(String key, bool visible, Object owner) {
  if (visible) {
    _owners[key] = owner;
  } else if (_owners[key] != null && !identical(_owners[key], owner)) {
    // A newer card for the same request owns the key now.
    return;
  } else {
    _owners.remove(key);
  }
  final current = visibleInlinePermissions.value;
  if (current.contains(key) == visible) return;
  visibleInlinePermissions.value = visible
      ? {...current, key}
      : ({...current}..remove(key));
}

/// Reports whether [child] is visible in its enclosing vertical scrollable.
///
/// Listens to that scrollable's position (no per-frame work while the list
/// is idle) and only writes to [visibleInlinePermissions] on change.
class InlinePermissionVisibility extends StatefulWidget {
  const InlinePermissionVisibility({
    required this.permissionKey,
    required this.active,
    required this.child,
    super.key,
  });

  /// [inlinePermissionKey] for the card, or null when it has no id.
  final String? permissionKey;

  /// Only pending requests take part; answered cards report nothing.
  final bool active;
  final Widget child;

  @override
  State<InlinePermissionVisibility> createState() =>
      _InlinePermissionVisibilityState();
}

class _InlinePermissionVisibilityState
    extends State<InlinePermissionVisibility> {
  ScrollPosition? _position;
  String? _reportedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void didUpdateWidget(InlinePermissionVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.permissionKey != widget.permissionKey ||
        oldWidget.active != widget.active) {
      _clear();
      _schedule();
    }
  }

  void _attach() {
    var state = Scrollable.maybeOf(context);
    while (state != null && state.position.axis != Axis.vertical) {
      state = Scrollable.maybeOf(state.context);
    }
    final position = state?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_check);
      _position = position;
      _position?.addListener(_check);
    }
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final key = widget.permissionKey;
    if (key == null || !widget.active) {
      _clear();
      return;
    }
    final box = context.findRenderObject();
    final position = _position;
    var visible = true;
    if (position != null && box is RenderBox && box.attached && box.hasSize) {
      final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is RenderBox && viewport.hasSize) {
        final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        final bottom = top + box.size.height;
        final height = viewport.size.height;
        // The action row sits at the bottom of the card: it counts as
        // visible once most of it is on screen.
        visible = bottom > 0 && bottom <= height + 24 && top < height;
      }
    }
    _reportedKey = key;
    _setVisible(key, visible, this);
  }

  void _clear() {
    final key = _reportedKey;
    if (key == null) return;
    _reportedKey = null;
    _setVisible(key, false, this);
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    // Never notify listeners while the tree is locked for disposal.
    final key = _reportedKey;
    if (key != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _setVisible(key, false, this),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
