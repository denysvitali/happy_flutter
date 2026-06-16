import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/input_toolbar.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/permission_mode_selector.dart'
    as perm;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('single-model sessions hide the dropdown affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          modelMode: ChatModelMode.defaultModel,
          availableModels: const [ChatModelMode.defaultModel],
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    final modelChip = find.byType(ModelChip);
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.smart_toy_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('multi-model sessions show the dropdown affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          modelMode: ChatModelMode.sonnet,
          availableModels: ChatModelMode.availableForFlavor('claude'),
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    final modelChip = find.byType(ModelChip);
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('codex model sessions use the reasoning icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          modelMode: ChatModelMode.fromString('gpt-5.5:high'),
          availableModels: [
            ChatModelMode.defaultModel,
            ChatModelMode.fromString('gpt-5.5:high'),
          ],
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    final modelChip = find.byType(ModelChip);
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.psychology_alt_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('toolbar chips expose semantics and compact height', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          permissionMode: null,
          onPermissionModeChanged: (_) {},
          modelMode: ChatModelMode.sonnet,
          availableModels: ChatModelMode.availableForFlavor('claude'),
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'Permission mode: Default')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'Model: Sonnet')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Profile: Default')), findsOneWidget);

    final modelSize = tester.getSize(find.byType(ModelChip));
    final profileSize = tester.getSize(find.byType(ProfileChip));

    expect(modelSize.height, lessThanOrEqualTo(30));
    expect(profileSize.height, lessThanOrEqualTo(30));
  });

  testWidgets(
    'toolbar is not horizontally scrollable — all chips stay visible at '
    'narrow widths',
    (tester) async {
      // Phone-portrait width; previously the SingleChildScrollView let the
      // row overflow off-screen and accepted horizontal drag gestures.
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 390,
            child: InputToolbar(
              permissionMode: perm.PermissionMode.bypassPermissions,
              onPermissionModeChanged: (_) {},
              modelMode: ChatModelMode.sonnet,
              availableModels: ChatModelMode.availableForFlavor('claude'),
              onShowModelPicker: () {},
              onShowProfilePicker: () {},
            ),
          ),
        ),
      );

      // No horizontal scroll view anywhere in the toolbar.
      expect(
        find.descendant(
          of: find.byType(InputToolbar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );

      // All three primary chips must be present and tappable.
      expect(find.byType(perm.PermissionModeSelector), findsOneWidget);
      expect(find.byType(ModelChip), findsOneWidget);
      expect(find.byType(ProfileChip), findsOneWidget);
    },
  );
}
