import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/components.dart'
    show ResizablePaneDivider, ResizableSplitView;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/pane_layout_storage.dart';

/// In-memory MMKV stand-in so the storage layer never touches the native
/// plugin during widget tests.
class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  final Map<String, String> values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  void setString(String key, String value) => values[key] = value;

  @override
  void removeKey(String key) => values.remove(key);
}

const _masterKey = Key('master-pane');

Widget _harness(PaneLayoutStorage storage, {String? dividerLabel}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ResizableSplitView(
        paneId: 'sessions',
        storage: storage,
        dividerSemanticsLabel: dividerLabel,
        master: const ColoredBox(
          key: _masterKey,
          color: Colors.blue,
          child: SizedBox.expand(),
        ),
        detail: const ColoredBox(color: Colors.green, child: SizedBox.expand()),
      ),
    ),
  );
}

double _masterWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(_masterKey)).width;

/// Lets [CachedStorage]'s 500ms persist debounce fire. Without this the
/// widget-test binding reports the pending timer as a leak and fails the
/// test even though the assertions passed.
Future<void> _drainPersistDebounce(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 600));

Finder _dividerSemantics() => find.descendant(
  of: find.byType(ResizablePaneDivider),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.child is GestureDetector,
  ),
);

void main() {
  late _FakeMMKVStorage mmkv;
  late PaneLayoutStorage storage;

  setUp(() {
    mmkv = _FakeMMKVStorage();
    storage = PaneLayoutStorage(storage: mmkv);
  });

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('default master pane keeps the detail visually dominant', (
    tester,
  ) async {
    setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(_harness(storage));

    // 38% leaves a stable master pane without giving it equal weight to the
    // operational detail surface.
    expect(_masterWidth(tester), closeTo(1024 * 0.38, 1));
    expect(_masterWidth(tester), lessThan(1024 * 0.55));
  });

  testWidgets('divider has a 44px target and supports arrow keys', (
    tester,
  ) async {
    setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(_harness(storage, dividerLabel: 'Resize'));

    final divider = find.byType(ResizablePaneDivider);
    expect(tester.getSize(divider).width, greaterThanOrEqualTo(44));

    final before = _masterWidth(tester);
    await tester.tap(divider);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      _masterWidth(tester),
      closeTo(before + ResizablePaneDivider.semanticsStep, 0.5),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_masterWidth(tester), closeTo(before, 0.5));
    await _drainPersistDebounce(tester);
  });

  testWidgets('dragging the divider resizes and persists the width', (
    tester,
  ) async {
    setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(_harness(storage));
    final before = _masterWidth(tester);

    await tester.drag(find.byType(ResizablePaneDivider), const Offset(60, 0));
    await tester.pumpAndSettle();

    final after = _masterWidth(tester);
    expect(after, greaterThan(before));
    expect(storage.widthFor('sessions'), closeTo(after, 1));

    // Written through on drag end — no debounce window in which a
    // backgrounded app would lose the user's choice.
    expect(mmkv.values['pane-layout-widths'], contains('sessions'));
    await _drainPersistDebounce(tester);
  });

  testWidgets('drag cannot collapse either pane', (tester) async {
    setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(_harness(storage));

    await tester.drag(find.byType(ResizablePaneDivider), const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(_masterWidth(tester), greaterThanOrEqualTo(200));

    await tester.drag(find.byType(ResizablePaneDivider), const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(_masterWidth(tester), lessThanOrEqualTo(1024 * 0.55 + 1));
    await _drainPersistDebounce(tester);
  });

  testWidgets('a persisted width is restored on the next build', (
    tester,
  ) async {
    storage.setWidthNow('sessions', 480);
    setViewport(tester, const Size(1024, 768));
    await tester.pumpWidget(_harness(storage));

    expect(_masterWidth(tester), closeTo(480, 1));
    await _drainPersistDebounce(tester);
  });

  testWidgets('a too-wide persisted width is clamped on a small viewport', (
    tester,
  ) async {
    storage.setWidthNow('sessions', 900);
    setViewport(tester, const Size(700, 900));
    await tester.pumpWidget(_harness(storage));

    expect(_masterWidth(tester), lessThanOrEqualTo(700 * 0.55 + 1));
    expect(_masterWidth(tester), greaterThan(0));
    await _drainPersistDebounce(tester);
  });

  testWidgets('the divider slider is operable and announces its width', (
    tester,
  ) async {
    setViewport(tester, const Size(1024, 768));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(storage, dividerLabel: 'Resize'));

    final before = _masterWidth(tester);
    // Target the operable node directly; descendants also include the
    // divider line's inherited semantics wrappers.
    final node = tester.getSemantics(_dividerSemantics());
    expect(node.label, 'Resize');
    expect(node.value, '${before.round()} pixels wide');
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);

    RendererBinding.instance.rootPipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.increase,
    );
    await tester.pumpAndSettle();
    expect(
      _masterWidth(tester),
      closeTo(before + ResizablePaneDivider.semanticsStep, 0.5),
    );

    // An assistive-tech nudge persists exactly like a drag does.
    expect(
      storage.widthFor('sessions'),
      closeTo(before + ResizablePaneDivider.semanticsStep, 0.5),
    );
    expect(mmkv.values['pane-layout-widths'], contains('sessions'));

    RendererBinding.instance.rootPipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.decrease,
    );
    await tester.pumpAndSettle();
    expect(_masterWidth(tester), closeTo(before, 0.5));

    await _drainPersistDebounce(tester);
    handle.dispose();
  });

  testWidgets('without a semantics label the divider is not a slider', (
    tester,
  ) async {
    setViewport(tester, const Size(1024, 768));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(storage));

    final node = tester.getSemantics(_dividerSemantics());
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.increase),
      isFalse,
    );
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.decrease),
      isFalse,
    );

    handle.dispose();
  });
}
