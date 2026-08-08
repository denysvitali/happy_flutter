import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/mcp_server.dart';
import 'package:happy_flutter/features/mcp/mcp_server_edit_screen.dart';

Widget _app(McpServer server) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: McpServerEditScreen(
      args: McpServerEditArgs(machineId: 'machine-1', server: server),
    ),
  );
}

void main() {
  test('secret controller preserves, replaces, adds, and removes safely', () {
    final controller = McpSecretMapController.fromWire({
      'TOKEN': 'plaintext-from-an-old-daemon',
      'KEEP': mcpRedactedValue,
    });

    expect(controller.toWire(), {
      'TOKEN': mcpRedactedValue,
      'KEEP': mcpRedactedValue,
    });

    controller
      ..replace('TOKEN', 'replacement-secret')
      ..add('NEW_TOKEN', 'new-secret')
      ..remove('KEEP');

    expect(controller.toWire(), {
      'TOKEN': 'replacement-secret',
      'NEW_TOKEN': 'new-secret',
    });
  });

  testWidgets('stdio editor shows secret presence without any value', (
    tester,
  ) async {
    const secret = 'do-not-render-this-token';
    final server = McpServer.fromJson(<String, dynamic>{
      'name': 'local-tool',
      'scope': 'user',
      'transport': 'stdio',
      'command': 'npx',
      'env': <String, String>{'TOKEN': secret},
      'enabled': true,
    });

    await tester.pumpWidget(_app(server));
    await tester.pumpAndSettle();

    expect(find.text('TOKEN'), findsOneWidget);
    expect(find.text('Stored securely'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text(mcpRedactedValue), findsNothing);
  });

  testWidgets('http editor masks authorization header presence', (
    tester,
  ) async {
    const secret = 'Bearer do-not-render';
    final server = McpServer.fromJson(<String, dynamic>{
      'name': 'remote-tool',
      'scope': 'user',
      'transport': 'http',
      'url': 'https://mcp.example/v1',
      'headers': <String, String>{'Authorization': secret},
      'enabled': true,
    });

    await tester.pumpWidget(_app(server));
    await tester.pumpAndSettle();

    expect(find.text('Authorization'), findsOneWidget);
    expect(find.text('Stored securely'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text(mcpRedactedValue), findsNothing);
  });
}
