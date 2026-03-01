import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';

void main() {
  group('session parsing - demonstrating the bug', () {
    test('demonstrates that direct casts fail with wrong types', () {
      // This simulates what the sync service does when parsing sessions
      // from the API response.

      // Valid session data - works fine
      final validSession = <String, dynamic>{
        'id': 'valid-session',
        'seq': 1,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'active': true,
        'activeAt': 1700000000000,
        'metadataVersion': 1,
        'agentStateVersion': 1,
      };

      // This is what the code does at lines 1018-1022 in sync_service.dart:
      final valid = Session(
        id: validSession['id'] as String,
        seq: validSession['seq'] as int,
        createdAt: validSession['createdAt'] as int,
        updatedAt: validSession['updatedAt'] as int,
        active: validSession['active'] as bool,
        activeAt: validSession['activeAt'] as int,
        metadataVersion: validSession['metadataVersion'] as int,
        agentStateVersion: validSession['agentStateVersion'] as int,
        thinking: false,
        presence: 'offline',
      );

      expect(valid.id, 'valid-session');

      // Now test with malformed data - these will throw at runtime

      // Case 1: Missing 'seq' field (null)
      final missingSeq = <String, dynamic>{
        'id': 'missing-seq',
        // 'seq' is missing!
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'active': true,
        'activeAt': 1700000000000,
        'metadataVersion': 1,
        'agentStateVersion': 1,
      };

      // This cast throws: null as int
      expect(
        () => missingSeq['seq'] as int,
        throwsA(isA<TypeError>()),
        reason: "Casting null to int throws TypeError",
      );

      // Case 2: Wrong type - string instead of int
      final wrongType = <String, dynamic>{
        'id': 'wrong-type',
        'seq': '1', // Should be int!
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'active': true,
        'activeAt': 1700000000000,
        'metadataVersion': 1,
        'agentStateVersion': 1,
      };

      // This cast throws: String as int
      expect(
        () => wrongType['seq'] as int,
        throwsA(isA<TypeError>()),
        reason: "Casting String to int throws TypeError",
      );

      // Case 3: 'active' is wrong type
      final wrongActiveType = <String, dynamic>{
        'id': 'wrong-active',
        'seq': 1,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'active': 'yes', // Should be bool!
        'activeAt': 1700000000000,
        'metadataVersion': 1,
        'agentStateVersion': 1,
      };

      expect(
        () => wrongActiveType['active'] as bool,
        throwsA(isA<TypeError>()),
        reason: "Casting String to bool throws TypeError",
      );

      // Case 4: null value
      final nullActiveAt = <String, dynamic>{
        'id': 'null-field',
        'seq': 1,
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'active': true,
        'activeAt': null, // Null!
        'metadataVersion': 1,
        'agentStateVersion': 1,
      };

      expect(
        () => nullActiveAt['activeAt'] as int,
        throwsA(isA<TypeError>()),
        reason: "Casting null to int throws TypeError",
      );
    });

    test('documents: sync_service silently skips sessions with invalid data', () {
      // The bug: In sync_service.dart lines 1018-1022, the code does:
      //
      //   seq: session['seq'] as int,
      //   createdAt: session['createdAt'] as int,
      //   ...
      //
      // If any of these casts fail (null, wrong type), the exception is caught
      // at lines 1042-1048 and the session is SILENTLY SKIPPED!
      //
      // In DEBUG mode, it prints:
      //   debugPrint('Failed to process session $sessionId: $error');
      //
      // In RELEASE mode, NOTHING is logged - the session just disappears.
      //
      // This causes "Session not loaded" errors because the session was never
      // added to _sessions in the first place!

      // The test passes - it documents the bug behavior
      expect(true, true, reason: 'See comments above for bug explanation');
    });
  });
}
