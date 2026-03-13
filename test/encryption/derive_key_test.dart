import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/derive_key.dart';

void main() {
  group('DeriveKey', () {
    group('deriveRoot', () {
      test('returns 32-byte key and 32-byte chain code', () async {
        final seed = Uint8List.fromList(List.generate(32, (i) => i));
        final state = await DeriveKey.deriveRoot(seed, 'test');

        expect(state.key.length, 32);
        expect(state.chainCode.length, 32);
      });

      test('is deterministic', () async {
        final seed = Uint8List.fromList(List.generate(32, (i) => i));

        final state1 = await DeriveKey.deriveRoot(seed, 'test');
        final state2 = await DeriveKey.deriveRoot(seed, 'test');

        expect(state1.key, state2.key);
        expect(state1.chainCode, state2.chainCode);
      });

      test('different usage produces different keys', () async {
        final seed = Uint8List.fromList(List.generate(32, (i) => i));

        final state1 = await DeriveKey.deriveRoot(seed, 'usage1');
        final state2 = await DeriveKey.deriveRoot(seed, 'usage2');

        expect(state1.key, isNot(equals(state2.key)));
      });

      test('different seed produces different keys', () async {
        final seed1 = Uint8List.fromList(List.generate(32, (i) => i));
        final seed2 = Uint8List.fromList(List.generate(32, (i) => 255 - i));

        final state1 = await DeriveKey.deriveRoot(seed1, 'test');
        final state2 = await DeriveKey.deriveRoot(seed2, 'test');

        expect(state1.key, isNot(equals(state2.key)));
      });
    });

    group('deriveChild', () {
      test('returns 32-byte key and 32-byte chain code', () async {
        final chainCode = Uint8List.fromList(List.generate(32, (i) => i));
        final state = await DeriveKey.deriveChild(chainCode, 'child');

        expect(state.key.length, 32);
        expect(state.chainCode.length, 32);
      });

      test('is deterministic', () async {
        final chainCode = Uint8List.fromList(List.generate(32, (i) => i));

        final state1 = await DeriveKey.deriveChild(chainCode, 'child');
        final state2 = await DeriveKey.deriveChild(chainCode, 'child');

        expect(state1.key, state2.key);
        expect(state1.chainCode, state2.chainCode);
      });

      test('different indices produce different keys', () async {
        final chainCode = Uint8List.fromList(List.generate(32, (i) => i));

        final state1 = await DeriveKey.deriveChild(chainCode, 'index1');
        final state2 = await DeriveKey.deriveChild(chainCode, 'index2');

        expect(state1.key, isNot(equals(state2.key)));
      });
    });

    group('derive (full path)', () {
      test('returns 32-byte key', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));
        final key = await DeriveKey.derive(master, 'test', ['path']);

        expect(key.length, 32);
      });

      test('is deterministic', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final key1 = await DeriveKey.derive(master, 'test', ['path']);
        final key2 = await DeriveKey.derive(master, 'test', ['path']);

        expect(key1, key2);
      });

      test('different usages produce different keys', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final key1 = await DeriveKey.derive(master, 'usage1', ['path']);
        final key2 = await DeriveKey.derive(master, 'usage2', ['path']);

        expect(key1, isNot(equals(key2)));
      });

      test('different paths produce different keys', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final key1 = await DeriveKey.derive(master, 'test', ['path1']);
        final key2 = await DeriveKey.derive(master, 'test', ['path2']);

        expect(key1, isNot(equals(key2)));
      });

      test('different path lengths produce different keys', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final key1 = await DeriveKey.derive(master, 'test', ['a']);
        final key2 = await DeriveKey.derive(master, 'test', ['a', 'b']);

        expect(key1, isNot(equals(key2)));
      });

      test('empty path returns root key', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final key = await DeriveKey.derive(master, 'test', []);

        // With empty path, should return root key
        final rootState = await DeriveKey.deriveRoot(master, 'test');
        expect(key, rootState.key);
      });

      test('order of path segments matters', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final key1 = await DeriveKey.derive(master, 'test', ['a', 'b']);
        final key2 = await DeriveKey.derive(master, 'test', ['b', 'a']);

        expect(key1, isNot(equals(key2)));
      });

      test('matches expected use case: Happy EnCoder content', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final contentKey =
            await DeriveKey.derive(master, 'Happy EnCoder', ['content']);

        expect(contentKey.length, 32);
        // Should be deterministic
        final contentKey2 =
            await DeriveKey.derive(master, 'Happy EnCoder', ['content']);
        expect(contentKey, contentKey2);
      });

      test('matches expected use case: Happy Coder analytics id', () async {
        final master = Uint8List.fromList(List.generate(32, (i) => i));

        final anonId = await DeriveKey.derive(
          master,
          'Happy Coder',
          ['analytics', 'id'],
        );

        expect(anonId.length, 32);
      });
    });

    group('KeyTreeState', () {
      test('holds key and chain code', () async {
        final seed = Uint8List.fromList(List.generate(32, (i) => i));
        final state = await DeriveKey.deriveRoot(seed, 'test');

        expect(state.key, isA<Uint8List>());
        expect(state.chainCode, isA<Uint8List>());
        expect(state.key.length, 32);
        expect(state.chainCode.length, 32);
      });
    });
  });
}
