import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/default_mcp_servers.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';

void main() {
  group('default MCP selection', () {
    test('all defaults leaves the selection unset', () {
      expect(mcpServersForSpawn({...kDefaultMcpServerIds}), isNull);
    });

    test('a subset and none are explicit selections', () {
      expect(mcpServersForSpawn({'loki'}), ['loki']);
      expect(mcpServersForSpawn({'github-actions'}), ['github-actions']);
      expect(mcpServersForSpawn({}), isEmpty);
    });

    test('controls only apply to supported providers', () {
      expect(supportsDefaultMcpServers('claude'), isTrue);
      expect(supportsDefaultMcpServers('codex'), isTrue);
      for (final agent in ['har', 'prime-agent', 'opencode', 'grok']) {
        expect(supportsDefaultMcpServers(agent), isFalse);
      }
    });
  });

  group('spawn MCP wire contract', () {
    SpawnSessionRequest request(List<String>? selection) => SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: '/workspace/project',
      sessionId: 'same-session',
      agent: 'claude',
      profileId: 'default',
      mcpServers: selection,
    );

    test('new default and restore requests omit both selection fields', () {
      expect(request(null).toJson(), isNot(contains('mcpServers')));
      expect(request(null).toJson(), isNot(contains('mcpServersSet')));
      const restore = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: '/workspace/project',
        isRestore: true,
      );
      expect(restore.toJson(), isNot(contains('mcpServers')));
      expect(restore.toJson(), isNot(contains('mcpServersSet')));
    });

    test('subset and none always include the presence bit', () {
      for (final selection in [
        <String>['loki'],
        <String>[],
      ]) {
        final json = request(selection).toJson();
        expect(json['mcpServers'], selection);
        expect(json['mcpServersSet'], isTrue);
      }
    });

    test('legacy profile retry preserves MCP selection and spawn identity', () {
      for (final selection in [
        <String>['loki'],
        <String>[],
      ]) {
        final before = request(selection).toJson();
        final after = request(selection).withoutProfileId().toJson();
        expect(after, {...before}..remove('profileId'));
      }
    });
  });
}
