import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';

void main() {
  group('WorkflowRun parsing', () {
    test('parses a minimal snapshot', () {
      final run = WorkflowRun.tryFromJson(const <String, dynamic>{
        'runId': 'wf_abc',
        'workflowName': 'inspect',
        'status': 'running',
      });
      expect(run, isNotNull);
      expect(run!.runId, 'wf_abc');
      expect(run.workflowName, 'inspect');
      expect(run.status, 'running');
      expect(run.phases, isEmpty);
      expect(run.workflowProgress, isEmpty);
    });

    test('parses a full snapshot and round-trips through JSON', () {
      final json = <String, dynamic>{
        'runId': 'wf_123',
        'taskId': 'task-1',
        'workflowName': 'probe',
        'summary': 'a short summary',
        'status': 'completed',
        'script': 'export const meta = {...}',
        'scriptPath': '/tmp/probe.js',
        'args': {'n': 3},
        'phases': [
          {'title': 'Scan', 'detail': 'scanning'},
        ],
        'defaultModel': 'claude-sonnet-4-6',
        'startTime': 1000,
        'durationMs': 5000,
        'agentCount': 2,
        'totalTokens': 1234,
        'totalToolCalls': 5,
        'error': null,
        'result': 'done',
        'logs': null,
        'workflowProgress': [
          {
            'type': 'workflow_phase',
            'index': 0,
            'title': 'Scan',
            'kind': 'start',
          },
          {
            'type': 'workflow_agent',
            'agentId': 'a1',
            'label': 'scanner',
            'phaseIndex': 0,
            'phaseTitle': 'Scan',
            'model': 'claude-sonnet-4-6',
            'state': 'done',
            'tokens': 100,
            'toolCalls': 2,
            'durationMs': 2000,
          },
          {
            'type': 'workflow_log',
            'message': 'starting scan',
          },
        ],
      };
      final run = WorkflowRun.tryFromJson(json);
      expect(run, isNotNull);
      final roundTripped = WorkflowRun.tryFromJson(run!.toJson());
      expect(roundTripped, run);
    });

    test('returns null when required fields are missing', () {
      expect(
        WorkflowRun.tryFromJson(const <String, dynamic>{
          'workflowName': 'probe',
          'status': 'running',
        }),
        isNull,
      );
      expect(
        WorkflowRun.tryFromJson(const <String, dynamic>{
          'runId': 'wf_123',
          'status': 'running',
        }),
        isNull,
      );
      expect(
        WorkflowRun.tryFromJson(const <String, dynamic>{
          'runId': 'wf_123',
          'workflowName': 'probe',
        }),
        isNull,
      );
    });

    test('skips malformed progress events', () {
      final run = WorkflowRun.tryFromJson(const <String, dynamic>{
        'runId': 'wf_x',
        'workflowName': 'x',
        'status': 'running',
        'workflowProgress': [
          {'type': 'workflow_agent'}, // missing required fields
          {'type': 'unknown_event'},
        ],
      });
      expect(run, isNotNull);
      expect(run!.workflowProgress, isEmpty);
    });
  });
}
