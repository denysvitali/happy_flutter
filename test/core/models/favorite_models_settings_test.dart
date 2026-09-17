import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/settings_update.dart';

void main() {
  group('Settings favoriteModelsByProfile', () {
    test('defaults to an empty map', () {
      final settings = Settings();

      expect(settings.favoriteModelsByProfile, <String, String>{});
      expect(settings.favoriteModelsByProfile, isA<Map<String, String>>());
    });

    test('round-trips through toJson/fromJson', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {
          'profile-1': 'claude-sonnet-4-6',
          'profile-2': 'gpt-5.2',
        };

      final restored = Settings.fromJson(settings.toJson());

      expect(
        restored.favoriteModelsByProfile,
        settings.favoriteModelsByProfile,
      );
      expect(
        identical(
          restored.favoriteModelsByProfile,
          settings.favoriteModelsByProfile,
        ),
        isFalse,
      );
    });

    test('drops malformed and null entries from JSON', () {
      final restored = Settings.fromJson(<String, dynamic>{
        'favoriteModelsByProfile': <dynamic, dynamic>{
          'good': 'model-a',
          'null-value': null,
          null: 'model-b',
        },
      });

      expect(restored.favoriteModelsByProfile, {'good': 'model-a'});
    });

    test('defaults to empty map when key missing from JSON', () {
      final restored = Settings.fromJson(<String, dynamic>{});

      expect(restored.favoriteModelsByProfile, <String, String>{});
    });

    test('falls back to default when JSON value is not a map', () {
      final restored = Settings.fromJson(<String, dynamic>{
        'favoriteModelsByProfile': 'not-a-map',
      });

      expect(restored.favoriteModelsByProfile, <String, String>{});
    });

    test('shallowClone produces an independent map', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'profile-1': 'model-a'};

      final clone = settings.shallowClone()
        ..favoriteModelsByProfile['profile-1'] = 'model-b';

      expect(settings.favoriteModelsByProfile['profile-1'], 'model-a');
      expect(clone.favoriteModelsByProfile['profile-1'], 'model-b');
      expect(settings, isNot(equals(clone)));
    });

    test('copyWith replaces the map without aliasing the input', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'profile-1': 'model-a'};

      final input = <String, String>{'profile-2': 'model-c'};
      final updated = settings.copyWith(favoriteModelsByProfile: input);
      input['profile-2'] = 'mutated';

      expect(updated.favoriteModelsByProfile['profile-2'], 'model-c');
      expect(settings.favoriteModelsByProfile, {'profile-1': 'model-a'});
    });

    test('copyWith without the argument preserves existing entries', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'profile-1': 'model-a'};

      final updated = settings.copyWith(themeMode: 'dark');

      expect(updated.favoriteModelsByProfile, {'profile-1': 'model-a'});
    });

    test('dispatcher applies the key in place via applyMutable', () {
      final settings = Settings();

      SettingsUpdate.applyMutable(settings, 'favoriteModelsByProfile', {
        'profile-1': 'model-a',
      });

      expect(settings.favoriteModelsByProfile, {'profile-1': 'model-a'});
    });

    test('dispatcher sets empty map for null value (removal)', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'profile-1': 'model-a'};

      SettingsUpdate.applyMutable(settings, 'favoriteModelsByProfile', null);

      expect(settings.favoriteModelsByProfile, <String, String>{});
    });

    test('dispatcher sanitizes non-string entries', () {
      final updated = SettingsUpdate.copyWithUpdated(
        Settings(),
        'favoriteModelsByProfile',
        <dynamic, dynamic>{1: 2},
      );

      expect(updated.favoriteModelsByProfile, {'1': '2'});
    });

    test('dispatcher returns an updated copy, original untouched', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'profile-1': 'model-a'};

      final updated = SettingsUpdate.copyWithUpdated(
        settings,
        'favoriteModelsByProfile',
        {'profile-1': 'model-b'},
      );

      expect(updated.favoriteModelsByProfile, {'profile-1': 'model-b'});
      expect(settings.favoriteModelsByProfile, {'profile-1': 'model-a'});
    });

    test('dispatcher drops null entries and tolerates malformed maps', () {
      final updated = SettingsUpdate.copyWithUpdated(
        Settings(),
        'favoriteModelsByProfile',
        <dynamic, dynamic>{'good': 'model-a', null: 'bad', 'bad': null},
      );
      expect(updated.favoriteModelsByProfile, {'good': 'model-a'});

      SettingsUpdate.applyMutable(updated, 'favoriteModelsByProfile', false);
      expect(updated.favoriteModelsByProfile, isEmpty);
    });

    test('removing one favorite preserves other profiles on roundtrip', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'a': 'model-a', 'b': 'model-b'};
      final remaining = {...settings.favoriteModelsByProfile}..remove('a');
      SettingsUpdate.applyMutable(
        settings,
        'favoriteModelsByProfile',
        remaining,
      );
      expect(Settings.fromJson(settings.toJson()).favoriteModelsByProfile, {
        'b': 'model-b',
      });
    });

    test('equality and hash ignore favorite insertion order', () {
      final settings = Settings()
        ..favoriteModelsByProfile = {'a': 'model-a', 'b': 'model-b'};
      final reordered = settings.copyWith(
        favoriteModelsByProfile: {'b': 'model-b', 'a': 'model-a'},
      );
      expect(reordered, settings);
      expect(reordered.hashCode, settings.hashCode);
      expect(
        settings.copyWith(favoriteModelsByProfile: {'a': 'changed'}),
        isNot(settings),
      );
    });

    test('normalizes null JSON values and respects fallback settings', () {
      expect(
        Settings.fromJson({
          'favoriteModelsByProfile': null,
        }).favoriteModelsByProfile,
        isEmpty,
      );
      final fallback = Settings()..favoriteModelsByProfile = {'a': 'model-a'};
      expect(
        Settings.fromJsonWithFallback({}, fallback).favoriteModelsByProfile,
        {'a': 'model-a'},
      );
      expect(
        Settings.fromJsonWithFallback({
          'favoriteModelsByProfile': <String, String>{},
        }, fallback).favoriteModelsByProfile,
        isEmpty,
      );
    });

    test('full settings payload still normalizes malformed entries', () {
      final json = Settings().toJson();
      // Fill nullable defaults to exercise the normalization fast path.
      for (final key in json.keys.toList()) {
        if (json[key] == null) {
          json[key] = key == 'reviewPromptLikedApp' ? false : '';
        }
      }
      json['favoriteModelsByProfile'] = <dynamic, dynamic>{
        'good': 'model-a',
        'bad': null,
        null: 'bad',
        1: 2,
      };
      expect(Settings.fromJson(json).favoriteModelsByProfile, {
        'good': 'model-a',
        '1': '2',
      });
    });

    test('key is recognized by isKnownKey', () {
      expect(SettingsUpdate.isKnownKey('favoriteModelsByProfile'), isTrue);
    });
  });
}
