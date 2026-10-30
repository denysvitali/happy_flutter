// Riverpod overrides that keep the gallery offline.
//
// Each stub mirrors the ones used by the widget tests (see
// `test/features/sessions/sessions_screen_tablet_split_test.dart`): state is
// seeded from fixtures and every `refreshFromSync` / network refresh is a
// no-op, so no screen ever tries to reach a server.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus, Machine;
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';

class GallerySettingsNotifier extends SettingsNotifier {
  GallerySettingsNotifier(this._initial);

  final Settings _initial;

  @override
  Settings build() => _initial;

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }

  @override
  Future<void> applySettings(Map<String, dynamic> values) async {
    final json = state.toJson()..addAll(values);
    state = Settings.fromJson(json);
  }
}

class _AuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;
}

class _SessionsNotifier extends SessionsNotifier {
  _SessionsNotifier(this._initial);

  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => SessionCollectionSnapshot(_initial);

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

class _MachinesNotifier extends MachinesNotifier {
  _MachinesNotifier(this._initial);

  final Map<String, Machine> _initial;

  @override
  Map<String, Machine> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

class _ConnectionNotifier extends ConnectionNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

class _NetworkNotifier extends NetworkNotifier {
  @override
  bool build() => true;
}

class _ProfileNotifier extends ProfileNotifier {
  @override
  Profile? build() => Profile(id: 'user-1', firstName: 'Denys');

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

class _CurrentSessionNotifier extends CurrentSessionNotifier {
  @override
  Session? build() => null;
}

class _GitStatusNotifier extends SessionGitStatusNotifier {
  @override
  Map<String, GitStatus> build() => const {};
}

class _LoopsNotifier extends LoopsNotifier {
  @override
  Map<String, List<Loop>> build() => const <String, List<Loop>>{};

  @override
  bool hydrateFromCache() => false;

  @override
  Future<void> refreshFromSync() async {}
}

class _ProviderUsageNotifier extends ProviderUsageNotifier {
  @override
  ProviderUsageSummary build() => const ProviderUsageSummary();

  @override
  Future<void> loadAccounts() async {}

  @override
  Future<void> refreshUsage() async {}
}

/// Overrides for one scene. [sessions] / [machines] feed the list-level
/// notifiers; the chat screen reads the same fixtures through `sync`.
List<Override> galleryOverrides({
  required Settings settings,
  required Map<String, Session> sessions,
  required Map<String, Machine> machines,
}) => [
  authStateNotifierProvider.overrideWith(_AuthNotifier.new),
  settingsNotifierProvider.overrideWith(
    () => GallerySettingsNotifier(settings),
  ),
  sessionsNotifierProvider.overrideWith(() => _SessionsNotifier(sessions)),
  machinesNotifierProvider.overrideWith(() => _MachinesNotifier(machines)),
  connectionNotifierProvider.overrideWith(_ConnectionNotifier.new),
  networkNotifierProvider.overrideWith(_NetworkNotifier.new),
  profileNotifierProvider.overrideWith(_ProfileNotifier.new),
  currentSessionNotifierProvider.overrideWith(_CurrentSessionNotifier.new),
  sessionGitStatusNotifierProvider.overrideWith(_GitStatusNotifier.new),
  loopsNotifierProvider.overrideWith(_LoopsNotifier.new),
  providerUsageNotifierProvider.overrideWith(_ProviderUsageNotifier.new),
];
