import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/settings/settings_section_registry.dart';
import 'package:happy_flutter/features/settings/widgets/settings_search_widgets.dart';

void main() {
  const spec = SettingsSectionSpec(
    title: 'Voice',
    description: 'Audio preferences',
    rows: [
      NavRouteRowSpec(
        icon: Icons.volume_up,
        title: 'Read aloud',
        route: 'read',
      ),
      NavRouteRowSpec(icon: Icons.mic, title: 'Microphone', route: 'mic'),
    ],
  );

  test('section qualifiers narrow results to the requested row', () {
    final result = filterSettingsSection(
      spec,
      settingsSearchTokens('voice microphone'),
    );
    expect(result!.rows, [spec.rows.last]);
    expect(
      filterSettingsSection(
        spec,
        settingsSearchTokens('audio microphone'),
      )!.rows,
      [spec.rows.last],
    );
  });

  test('unknown tokens cannot fall back to an unrelated partial match', () {
    expect(
      filterSettingsSection(spec, settingsSearchTokens('microphone missing')),
      isNull,
    );
  });

  test('tokens spanning rows keep both relevant rows', () {
    expect(
      filterSettingsSection(
        spec,
        settingsSearchTokens('aloud microphone'),
      )!.rows,
      spec.rows,
    );
  });

  testWidgets('clear and Escape retain input focus for another search', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'voice');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) =>
                SettingsSearchField(controller: controller, query: value.text),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'sessions');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });
}
