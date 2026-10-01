import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
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

  testWidgets('provider-owned model labels remain visible and readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          resolvedModelLabel: 'GLM-5',
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('GLM-5'));
    expect(label.style?.fontSize, greaterThanOrEqualTo(11));
    expect(find.bySemanticsLabel(RegExp(r'^Model: GLM-5')), findsOneWidget);
  });

  testWidgets('compact toolbar moves profile and context into options', (
    tester,
  ) async {
    var profileOpened = 0;
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          compact: true,
          modelMode: ChatModelMode.sonnet,
          contextSize: 12000,
          onShowModelPicker: () {},
          onShowProfilePicker: () => profileOpened++,
        ),
      ),
    );
    expect(find.byType(ModelChip), findsOneWidget);
    expect(find.byType(ProfileChip), findsNothing);
    expect(find.byType(ContextSizeIndicator), findsNothing);
    await tester.tap(find.byKey(const ValueKey('composer-options-button')));
    await tester.pumpAndSettle();
    expect(find.text('Context usage'), findsOneWidget);
    expect(find.byType(ContextSizeIndicator), findsOneWidget);
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    expect(profileOpened, 1);
    expect(find.text('Context usage'), findsNothing);
  });

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
    // Routine settings carry no decorative icon.
    expect(
      find.descendant(of: modelChip, matching: find.byType(Icon)),
      findsNothing,
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
    // The chevron is the only glyph; no decorative model icon.
    expect(
      find.descendant(of: modelChip, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('codex model chips show the model without a badge icon', (
    tester,
  ) async {
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
      findsNothing,
    );
    expect(
      find.descendant(of: modelChip, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('codex sessions show only codex permission modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          sessionFlavor: 'codex',
          permissionMode: perm.PermissionMode.defaultMode,
          onPermissionModeChanged: (_) {},
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    await tester.tap(find.byType(perm.PermissionModeSelector));
    await tester.pumpAndSettle();

    expect(find.text('Read-only'), findsOneWidget);
    expect(find.text('Safe Yolo'), findsOneWidget);
    expect(find.text('Yolo'), findsOneWidget);
    expect(find.text('Accept Edits'), findsNothing);
    expect(find.text('Plan'), findsNothing);
  });

  testWidgets('toolbar chips expose semantics and min hit targets', (
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
      find.bySemanticsLabel(RegExp(r'Approvals: Default')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'Model: Sonnet')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Profile: Default')), findsOneWidget);

    final modelSize = tester.getSize(find.byType(ModelChip));
    final profileSize = tester.getSize(find.byType(ProfileChip));

    // Visual chip is dense (~32) but hit target pads to AppTouchTarget.min.
    expect(modelSize.height, greaterThanOrEqualTo(44));
    expect(profileSize.height, greaterThanOrEqualTo(44));
    expect(modelSize.width, greaterThanOrEqualTo(44));
    expect(profileSize.width, greaterThanOrEqualTo(44));
  });

  testWidgets('permission, model, and profile chips share one scrollable row', (
    tester,
  ) async {
    // Regression: wrapping long provider/model labels onto a second row
    // doubled the composer toolbar height and made the layout look broken.
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 390,
          child: InputToolbar(
            permissionMode: perm.PermissionMode.defaultMode,
            onPermissionModeChanged: (_) {},
            modelMode: ChatModelMode.sonnet,
            availableModels: ChatModelMode.availableForFlavor('claude'),
            onShowModelPicker: () {},
            onShowProfilePicker: () {},
          ),
        ),
      ),
    );

    final permCenter = tester.getCenter(
      find.byType(perm.PermissionModeSelector),
    );
    final modelCenter = tester.getCenter(find.byType(ModelChip));
    final profileCenter = tester.getCenter(find.byType(ProfileChip));

    // Same baseline (allow 1px float noise).
    expect((permCenter.dy - modelCenter.dy).abs(), lessThan(1));
    expect((modelCenter.dy - profileCenter.dy).abs(), lessThan(1));

    // Left-to-right order: permission → model → profile.
    expect(permCenter.dx, lessThan(modelCenter.dx));
    expect(modelCenter.dx, lessThan(profileCenter.dx));

    // Toolbar itself must stay a single chip-height strip, not 3 stacks.
    final toolbarSize = tester.getSize(find.byType(InputToolbar));
    expect(toolbarSize.height, lessThan(60));

    // Long labels overflow into a horizontal lane instead of wrapping.
    expect(
      find.descendant(
        of: find.byType(InputToolbar),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'profile chip semantics include backend host so misroutes are audible',
    (tester) async {
      // Regression: name "Qwen 3.8" + env → kimi.com was invisible on the
      // chip; only the picker subtitle showed the host after the first fix.
      final misrouted = AIBackendProfile(
        id: 'custom-qwen-misrouted',
        name: 'Qwen 3.8',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.kimi.com/coding/',
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          InputToolbar(
            modelMode: ChatModelMode.defaultModel,
            availableModels: const [ChatModelMode.defaultModel],
            selectedProfile: misrouted,
            onShowModelPicker: () {},
            onShowProfilePicker: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Profile: Qwen 3\.8 · api\.kimi\.com')),
        findsOneWidget,
      );
      // Visible label still the short name (chip width is capped).
      expect(find.text('Qwen 3.8'), findsOneWidget);
    },
  );
}
