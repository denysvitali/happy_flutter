import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/default_mcp_servers.dart';
import 'package:happy_flutter/features/sessions/widgets/kubernetes_mcp_section.dart';

void main() {
  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    var selected = {...kDefaultMcpServerIds};
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => KubernetesMcpSection(
                selected: selected,
                enabled: enabled,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('k8s-mcp-servers')));
    await tester.pumpAndSettle();
  }

  testWidgets('all selected by default; each server can be disabled', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('All enabled'), findsOneWidget);
    final github = find.byKey(const ValueKey('k8s-mcp-github-actions'));
    final loki = find.byKey(const ValueKey('k8s-mcp-loki'));
    expect(tester.widget<SwitchListTile>(github).value, isTrue);
    expect(tester.widget<SwitchListTile>(loki).value, isTrue);
    await tester.tap(github);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(github).value, isFalse);
    expect(tester.widget<SwitchListTile>(loki).value, isTrue);
    await tester.tap(loki);
    await tester.pumpAndSettle();
    expect(find.text('None enabled'), findsOneWidget);
    await tester.tap(github);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(github).value, isTrue);
  });

  testWidgets('selection is locked while creating a session', (tester) async {
    await pump(tester, enabled: false);
    for (final id in kDefaultMcpServerIds) {
      final tile = tester.widget<SwitchListTile>(
        find.byKey(ValueKey('k8s-mcp-$id')),
      );
      expect(tile.onChanged, isNull);
      expect(tile.value, isTrue);
    }
  });
}
