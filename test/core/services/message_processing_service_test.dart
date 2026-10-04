import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/json_text.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/services/message_processing_service.dart';

void main() {
  Map<String, dynamic> wire(int seq) => {
    'id': 'server-$seq',
    'localId': 'local-$seq',
    'seq': seq,
    'createdAt': seq * 1000,
  };

  Map<String, dynamic> user(String text) => {
    'role': 'user',
    'content': {'type': 'text', 'text': text},
  };

  Map<String, dynamic> toolResult(String text) => {
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {'type': 'tool-result', 'id': 'call-1', 'output': text},
    },
  };

  void expectSameResult(ProcessedMessages actual, ProcessedMessages expected) {
    expect(actual.messages, expected.messages);
    expect(actual.toolResults, expected.toolResults);
    expect(actual.usageUpdates, expected.usageUpdates);
    expect(actual.droppedReasons, expected.droppedReasons);
    expect(actual.maxSeq, expected.maxSeq);
    expect(
      actual.undecryptableRenderedCount,
      expected.undecryptableRenderedCount,
    );
  }

  tearDown(() => debugMessageProcessingDispatch = null);

  test(
    'small mixed bodies retain identical inline and worker semantics',
    () async {
      final bodies = <dynamic>[
        user('continue'),
        JsonText(jsonEncode(user('continue'))),
        toolResult('complete'),
      ];
      final wires = [wire(1), wire(2), wire(3)];
      final dispatches = <bool>[];
      debugMessageProcessingDispatch = dispatches.add;

      final inline = await processDecryptedMessagesWithIsolation(
        decryptedJsonList: bodies,
        wireMessages: wires,
        sessionId: 's',
        wasEncrypted: const [false, true, false],
        useIsolate: false,
      );
      final worker = await processDecryptedMessagesWithIsolation(
        decryptedJsonList: bodies,
        wireMessages: wires,
        sessionId: 's',
        wasEncrypted: const [false, true, false],
        useIsolate: true,
      );

      expect(dispatches, [false, true]);
      expectSameResult(worker, inline);
      expect(worker.messages.map((row) => row['localId']), [
        'local-1',
        'local-2',
      ]);
      expect(worker.messages.map((row) => row['content']), [
        'continue',
        'continue',
      ]);
      expect(worker.toolResults.single['toolUseId'], 'call-1');
      expect(bodies[1], isA<JsonText>());
    },
  );

  test(
    'a large single JsonText row dispatches all parsing to the worker',
    () async {
      final output = 'tool output ' * 12000;
      final bodies = <dynamic>[JsonText(jsonEncode(toolResult(output)))];
      final wires = [wire(4)];
      final dispatches = <bool>[];
      debugMessageProcessingDispatch = dispatches.add;
      final expected = processDecryptedMessages(
        decryptedJsonList: bodies,
        wireMessages: wires,
        sessionId: 's',
        wasEncrypted: const [true],
      );

      final actual = await processDecryptedMessagesWithIsolation(
        decryptedJsonList: bodies,
        wireMessages: wires,
        sessionId: 's',
        wasEncrypted: const [true],
        useIsolate: false,
      );

      expect(dispatches, [true]);
      expectSameResult(actual, expected);
      expect(actual.toolResults.single['result'], output);
      expect(actual.maxSeq, 4);
    },
  );

  test(
    'large decoded mixed bodies preserve input order and identity',
    () async {
      final output = 'large decoded output ' * 8000;
      final bodies = <dynamic>[
        user('continue'),
        toolResult(output),
        JsonText(jsonEncode(user('continue'))),
      ];
      final wires = [wire(5), wire(6), wire(7)];
      final expected = processDecryptedMessages(
        decryptedJsonList: bodies,
        wireMessages: wires,
        sessionId: 's',
        wasEncrypted: const [false, false, true],
      );
      final dispatches = <bool>[];
      debugMessageProcessingDispatch = dispatches.add;

      final actual = await processDecryptedMessagesWithIsolation(
        decryptedJsonList: bodies,
        wireMessages: wires,
        sessionId: 's',
        wasEncrypted: const [false, false, true],
        useIsolate: false,
      );

      expect(dispatches, [true]);
      expectSameResult(actual, expected);
      expect(actual.messages.map((row) => row['localId']), [
        'local-5',
        'local-7',
      ]);
      expect(actual.toolResults.single['result'], output);
      expect(
        (bodies[1] as Map<String, dynamic>)['content'],
        toolResult(output)['content'],
      );
    },
  );

  test('many tiny fields cross the bounded sizing traversal', () async {
    final body = user('hello')..['metadata'] = List<int>.filled(5000, 1);
    final dispatches = <bool>[];
    debugMessageProcessingDispatch = dispatches.add;

    final actual = await processDecryptedMessagesWithIsolation(
      decryptedJsonList: [body],
      wireMessages: [wire(8)],
      sessionId: 's',
      wasEncrypted: const [false],
      useIsolate: false,
    );

    expect(dispatches, [true]);
    expect(actual.messages.single['localId'], 'local-8');
    expect(actual.messages.single['content'], 'hello');
  });
}
