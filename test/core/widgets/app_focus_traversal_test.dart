import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/widgets/app_focus_traversal.dart';

void main() {
  testWidgets('Tab and Shift-Tab skip attached nodes awaiting layout', (
    tester,
  ) async {
    final first = FocusNode();
    final pending = FocusNode();
    final last = FocusNode();
    final laidOut = ValueNotifier(false);
    final policy = AppReadingOrderTraversalPolicy();
    addTearDown(first.dispose);
    addTearDown(pending.dispose);
    addTearDown(last.dispose);
    addTearDown(laidOut.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: FocusTraversalGroup(
          policy: policy,
          child: Column(
            children: [
              Focus(
                focusNode: first,
                child: const SizedBox.square(dimension: 30),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: laidOut,
                builder: (context, ready, child) =>
                    ready ? child! : _BeforeFirstLayout(child: child!),
                child: Focus(
                  focusNode: pending,
                  child: const SizedBox.square(dimension: 30),
                ),
              ),
              Focus(
                focusNode: last,
                child: const SizedBox.square(dimension: 30),
              ),
            ],
          ),
        ),
      ),
    );
    final pendingBox = pending.context!.findRenderObject()! as RenderBox;
    expect(pendingBox.attached, isTrue);
    expect(pendingBox.hasSize, isFalse);

    first.requestFocus();
    await tester.pump();
    expect(policy.inDirection(first, TraversalDirection.down), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(last.hasPrimaryFocus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);

    // Candidates become reachable automatically once their layout completes.
    laidOut.value = true;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(pending.hasPrimaryFocus, isTrue);
    expect(policy.inDirection(pending, TraversalDirection.down), isTrue);
    await tester.pump();
    expect(last.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading order follows geometry and RTL direction', (
    tester,
  ) async {
    final left = FocusNode();
    final right = FocusNode();
    addTearDown(left.dispose);
    addTearDown(right.dispose);
    final policy = AppReadingOrderTraversalPolicy();
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: FocusTraversalGroup(
              policy: policy,
              child: Stack(
                children: [
                  Positioned(
                    left: 100,
                    top: 0,
                    child: Focus(
                      focusNode: right,
                      child: const SizedBox.square(dimension: 30),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Focus(
                      focusNode: left,
                      child: const SizedBox.square(dimension: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        policy.sortDescendants([right, left], left),
        direction == TextDirection.ltr ? [left, right] : [right, left],
      );
      expect(
        policy.findFirstFocus(left, ignoreCurrentFocus: true),
        direction == TextDirection.ltr ? left : right,
      );
      expect(
        policy.findLastFocus(left, ignoreCurrentFocus: true),
        direction == TextDirection.ltr ? right : left,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty candidates and unlaid-out current focus stay safe', (
    tester,
  ) async {
    final pending = FocusNode();
    addTearDown(pending.dispose);
    final policy = AppReadingOrderTraversalPolicy();
    await tester.pumpWidget(
      MaterialApp(
        home: FocusTraversalGroup(
          policy: policy,
          child: _BeforeFirstLayout(
            child: Focus(
              focusNode: pending,
              child: const SizedBox.square(dimension: 30),
            ),
          ),
        ),
      ),
    );
    expect(policy.sortDescendants([pending], pending), isEmpty);
    expect(policy.findFirstFocus(pending, ignoreCurrentFocus: true), pending);
    expect(policy.findLastFocus(pending, ignoreCurrentFocus: true), pending);
    pending.requestFocus();
    await tester.pump();
    expect(policy.next(pending), isFalse);
    expect(policy.previous(pending), isFalse);
    expect(policy.inDirection(pending, TraversalDirection.down), isFalse);
    expect(pending.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}

/// Models the interval between attaching a subtree and its first layout.
class _BeforeFirstLayout extends SingleChildRenderObjectWidget {
  const _BeforeFirstLayout({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBeforeFirstLayout();
}

class _RenderBeforeFirstLayout extends RenderProxyBox {
  @override
  void performLayout() {
    size = constraints.smallest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}
