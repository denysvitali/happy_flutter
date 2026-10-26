import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/features/chat/model_selection_resolver.dart';
import 'package:happy_flutter/features/chat/widgets/input_toolbar.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/permission_mode_selector.dart';

void main() {
  const catalog = [
    PrimeAgentModelInfo(id: 'codex/gpt-6.1-terra', name: 'GPT-6.1 Terra'),
    PrimeAgentModelInfo(id: 'provider/model:variant', name: 'Provider variant'),
  ];
  test('Har catalog ignores profile models and reasoning variants', () {
    final models = ChatModelMode.availableForProfile(
      flavor: 'har',
      claudeCompatible: true,
      profileModels: ['opus:max', 'unadvertised-model'],
      harModels: catalog,
    );
    expect(models.map((m) => m.modeString), [
      'codex/gpt-6.1-terra',
      'provider/model:variant',
    ]);
    expect(models.every((m) => m.reasoningEffort == null), isTrue);
    expect(ChatModelMode.normalizeRawForFlavor('opus:max', 'har'), 'default');
    expect(normalizeAgentKey('har'), 'har');
  });

  test('Har restores running model before stale draft and global choices', () {
    final resolution = resolveModelSelection(
      savedPermissionMode: 'plan',
      savedModelMode: 'codex/gpt-6.1-sol',
      savedProfileId: null,
      sessionModelMode: 'codex/gpt-6.1-terra',
      harModels: catalog,
      sessionPermissionMode: 'default',
      flavor: 'har',
      settingsProfiles: [],
      builtInProfiles: [],
      lastUsedModelMode: 'opus:max',
    );
    expect(resolution.resolvedRawModelString, 'codex/gpt-6.1-terra');
    expect(resolution.resolvedModelMode.label, 'GPT-6.1 Terra');
    expect(resolution.resolvedPermissionMode, PermissionMode.bypassPermissions);
  });

  test('Har preserves the running model without an advertised catalog', () {
    final resolution = resolveModelSelection(
      savedPermissionMode: null,
      savedModelMode: 'stale/model',
      savedProfileId: null,
      sessionModelMode: 'provider/model:variant',
      sessionPermissionMode: null,
      flavor: 'har',
      settingsProfiles: [],
      builtInProfiles: [],
      lastUsedModelMode: 'codex/gpt-6-luna',
    );
    expect(resolution.resolvedRawModelString, 'provider/model:variant');
    expect(resolution.resolvedModelMode.reasoningEffort, isNull);
    expect(ChatModelMode.availableForFlavor('har'), isEmpty);
  });

  testWidgets('Har composer exposes fixed policy and locks configuration', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InputToolbar(
            sessionFlavor: 'har',
            availableModels: ChatModelMode.fromHarCatalog(catalog),
            onShowModelPicker: () => picks++,
            onShowProfilePicker: () => picks++,
          ),
        ),
      ),
    );
    expect(find.text('Host · approvals disabled'), findsOneWidget);
    expect(find.text('Model fixed for this conversation'), findsNothing);
    expect(tester.widget<ModelChip>(find.byType(ModelChip)).enabled, isTrue);
    expect(find.byType(ProfileChip), findsNothing);
    expect(find.byType(PermissionModeSelector), findsNothing);
    await tester.tap(find.byType(ModelChip));
    expect(picks, 1);
  });

  testWidgets('Har composer disables model selection without a catalog', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InputToolbar(
            sessionFlavor: 'har',
            modelMode: ChatModelMode.fromHarCatalog(catalog).first,
            availableModels: const [],
            onShowModelPicker: () => picks++,
            onShowProfilePicker: () => picks++,
          ),
        ),
      ),
    );
    expect(find.text('GPT-6.1 Terra'), findsOneWidget);
    expect(tester.widget<ModelChip>(find.byType(ModelChip)).enabled, isFalse);
    await tester.tap(find.byType(ModelChip));
    expect(picks, 0);
  });
}
