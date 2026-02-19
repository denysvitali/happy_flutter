import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/message.dart';

void main() {
  group('ApiMessage.fromJson', () {
    test('parses id, seq, content, and createdAt correctly', () {
      final json = {
        'id': 'msg-123',
        'seq': 42,
        'content': {
          't': 'text',
          'c': 'Hello, world!',
        },
        'createdAt': 1700000000,
      };

      final message = ApiMessage.fromJson(json);

      expect(message.id, 'msg-123');
      expect(message.seq, 42);
      expect(message.createdAt, 1700000000);
      expect(message.content.t, 'text');
      expect(message.content.c, 'Hello, world!');
    });

    test('parses optional localId when present', () {
      final json = {
        'id': 'msg-456',
        'seq': 1,
        'localId': 'local-abc',
        'content': {'t': 'text', 'c': 'Test message'},
        'createdAt': 1700000001,
      };

      final message = ApiMessage.fromJson(json);

      expect(message.localId, 'local-abc');
    });

    test('handles missing localId (returns null)', () {
      final json = {
        'id': 'msg-789',
        'seq': 5,
        'content': {'t': 'markdown', 'c': '**Bold**'},
        'createdAt': 1700000002,
      };

      final message = ApiMessage.fromJson(json);

      expect(message.localId, isNull);
    });

    test('toJson serializes correctly', () {
      final json = {
        'id': 'msg-round-trip',
        'seq': 10,
        'content': {'t': 'text', 'c': 'Round trip content'},
        'createdAt': 1700000003,
      };

      final message = ApiMessage.fromJson(json);
      final serialized = message.toJson();

      expect(serialized['id'], 'msg-round-trip');
      expect(serialized['seq'], 10);
      expect(serialized['createdAt'], 1700000003);
      expect((serialized['content'] as Map)['c'], 'Round trip content');
    });
  });

  group('ApiMessageContent.fromJson', () {
    test('parses t and c fields', () {
      final json = {'t': 'markdown', 'c': '# Header'};
      final content = ApiMessageContent.fromJson(json);

      expect(content.t, 'markdown');
      expect(content.c, '# Header');
    });

    test('round-trip fromJson/toJson', () {
      final json = {'t': 'text', 'c': 'Simple text'};
      final content = ApiMessageContent.fromJson(json);
      final serialized = content.toJson();

      expect(serialized['t'], 'text');
      expect(serialized['c'], 'Simple text');
    });
  });

  group('ToolCall.fromJson', () {
    test('parses state field running', () {
      final json = {
        'name': 'BashTool',
        'state': 'running',
        'createdAt': 1700000000,
      };

      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.name, 'BashTool');
      expect(toolCall.state, 'running');
      expect(toolCall.createdAt, 1700000000);
    });

    test('parses state field completed', () {
      final json = {
        'name': 'ReadFileTool',
        'state': 'completed',
        'createdAt': 1700000001,
        'completedAt': 1700000002,
        'result': {'output': 'file contents'},
      };

      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.state, 'completed');
      expect(toolCall.completedAt, 1700000002);
    });

    test('parses state field error', () {
      final json = {
        'name': 'SearchTool',
        'state': 'error',
        'createdAt': 1700000003,
        'description': 'Search failed',
      };

      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.state, 'error');
      expect(toolCall.description, 'Search failed');
    });

    test('parses optional fields correctly', () {
      final json = {
        'name': 'WriteFileTool',
        'state': 'running',
        'input': {'path': '/tmp/file.txt', 'content': 'data'},
        'createdAt': 1700000004,
        'startedAt': 1700000005,
        'description': 'Writing file',
      };

      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.input, isNotNull);
      expect(toolCall.startedAt, 1700000005);
      expect(toolCall.description, 'Writing file');
    });

    test('handles null optional fields', () {
      final json = {
        'name': 'SomeTool',
        'state': 'running',
        'createdAt': 1700000006,
      };

      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.input, isNull);
      expect(toolCall.startedAt, isNull);
      expect(toolCall.completedAt, isNull);
      expect(toolCall.description, isNull);
      expect(toolCall.result, isNull);
      expect(toolCall.permission, isNull);
    });

    test('parses permission field', () {
      final json = {
        'name': 'BashTool',
        'state': 'running',
        'createdAt': 1700000007,
        'permission': {
          'id': 'perm-1',
          'status': 'pending',
        },
      };

      final toolCall = ToolCall.fromJson(json);

      expect(toolCall.permission, isNotNull);
      expect(toolCall.permission!.id, 'perm-1');
      expect(toolCall.permission!.status, 'pending');
    });
  });

  group('AgentEvent.fromJson', () {
    test('parses switch event type', () {
      final json = {
        'type': 'switch',
        'mode': 'auto',
      };

      final event = AgentEvent.fromJson(json);

      expect(event, isA<SwitchEvent>());
      expect((event as SwitchEvent).mode, 'auto');
    });

    test('parses message event type', () {
      final json = {
        'type': 'message',
        'message': 'Claude is thinking...',
      };

      final event = AgentEvent.fromJson(json);

      expect(event, isA<MessageEvent>());
      expect((event as MessageEvent).message, 'Claude is thinking...');
    });

    test('parses limit-reached event type', () {
      final json = {
        'type': 'limit-reached',
        'endsAt': 1700009999,
      };

      final event = AgentEvent.fromJson(json);

      expect(event, isA<LimitReached>());
      expect((event as LimitReached).endsAt, 1700009999);
    });

    test('parses ready event type', () {
      final json = {'type': 'ready'};

      final event = AgentEvent.fromJson(json);

      expect(event, isA<ReadyEvent>());
    });

    test('returns UnknownEvent for unrecognized type', () {
      final json = {'type': 'unknown-future-type'};

      final event = AgentEvent.fromJson(json);

      expect(event, isA<UnknownEvent>());
    });

    test('SwitchEvent with different modes', () {
      for (final mode in ['auto', 'manual', 'plan']) {
        final event = AgentEvent.fromJson({'type': 'switch', 'mode': mode});
        expect(event, isA<SwitchEvent>());
        expect((event as SwitchEvent).mode, mode);
      }
    });
  });

  group('MessageMeta.fromJson', () {
    test('parses all optional fields when present', () {
      final json = {
        'sentFrom': 'user',
        'permissionMode': 'auto',
        'model': 'claude-3',
        'fallbackModel': 'claude-2',
        'customSystemPrompt': 'Be concise.',
        'appendSystemPrompt': 'Extra context.',
        'allowedTools': ['bash', 'read'],
        'disallowedTools': ['write'],
        'displayText': 'Shown to user',
      };

      final meta = MessageMeta.fromJson(json);

      expect(meta.sentFrom, 'user');
      expect(meta.permissionMode, 'auto');
      expect(meta.model, 'claude-3');
      expect(meta.fallbackModel, 'claude-2');
      expect(meta.customSystemPrompt, 'Be concise.');
      expect(meta.appendSystemPrompt, 'Extra context.');
      expect(meta.allowedTools, ['bash', 'read']);
      expect(meta.disallowedTools, ['write']);
      expect(meta.displayText, 'Shown to user');
    });

    test('handles all null values gracefully', () {
      final json = <String, dynamic>{};

      final meta = MessageMeta.fromJson(json);

      expect(meta.sentFrom, isNull);
      expect(meta.permissionMode, isNull);
      expect(meta.model, isNull);
      expect(meta.fallbackModel, isNull);
      expect(meta.customSystemPrompt, isNull);
      expect(meta.appendSystemPrompt, isNull);
      expect(meta.allowedTools, isNull);
      expect(meta.disallowedTools, isNull);
      expect(meta.displayText, isNull);
    });

    test('parses partial fields', () {
      final json = {
        'sentFrom': 'agent',
        'model': 'claude-opus-4',
      };

      final meta = MessageMeta.fromJson(json);

      expect(meta.sentFrom, 'agent');
      expect(meta.model, 'claude-opus-4');
      expect(meta.permissionMode, isNull);
    });

    test('toJson omits null fields', () {
      const meta = MessageMeta(
        sentFrom: 'user',
        model: 'claude-3',
      );

      final json = meta.toJson();

      expect(json['sentFrom'], 'user');
      expect(json['model'], 'claude-3');
      expect(json.containsKey('permissionMode'), isFalse);
      expect(json.containsKey('fallbackModel'), isFalse);
    });

    test('toJson includes all non-null fields', () {
      const meta = MessageMeta(
        sentFrom: 'user',
        permissionMode: 'manual',
        allowedTools: ['bash'],
        disallowedTools: ['write'],
      );

      final json = meta.toJson();

      expect(json['sentFrom'], 'user');
      expect(json['permissionMode'], 'manual');
      expect(json['allowedTools'], ['bash']);
      expect(json['disallowedTools'], ['write']);
    });
  });

  group('Permission.fromJson', () {
    test('parses required fields', () {
      final json = {
        'id': 'perm-abc',
        'status': 'approved',
      };

      final perm = Permission.fromJson(json);

      expect(perm.id, 'perm-abc');
      expect(perm.status, 'approved');
    });

    test('parses optional fields', () {
      final json = {
        'id': 'perm-xyz',
        'status': 'pending',
        'reason': 'Need shell access',
        'mode': 'auto',
        'allowedTools': ['bash', 'read'],
        'decision': 'allow',
        'date': 1700000010,
      };

      final perm = Permission.fromJson(json);

      expect(perm.reason, 'Need shell access');
      expect(perm.mode, 'auto');
      expect(perm.allowedTools, ['bash', 'read']);
      expect(perm.decision, 'allow');
      expect(perm.date, 1700000010);
    });
  });
}
