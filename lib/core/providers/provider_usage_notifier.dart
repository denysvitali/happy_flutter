import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/provider_usage_api.dart';
import '../models/provider_usage.dart';
import '../services/logger_service.dart' show logger;
import '../services/provider_usage_storage.dart';
import 'settings_notifier.dart' show settingsNotifierProvider;

/// Riverpod notifier for third-party LLM provider usage.
///
/// Holds the list of configured accounts, their latest usage, and loading
/// state. Fetching is explicit (pull-to-refresh / init) so the tab does not
/// wake the app on every sync tick.
class ProviderUsageNotifier extends Notifier<ProviderUsageSummary> {
  late final ProviderUsageStorage _storage;
  late final KimiUsageApi _kimiApi;
  late final MiniMaxUsageApi _miniMaxApi;
  late final ZaiUsageApi _zaiApi;
  late final GrokUsageApi _grokApi;
  late final QwenUsageApi _qwenApi;

  /// Per-account failure tracking so a dead key/network blip does not spam
  /// Loki with a full stack every refresh. Backoff starts at 30s and doubles
  /// up to 15 minutes; a successful fetch clears the strike.
  ///
  /// The map is hydrated from [ProviderUsageStorage] on the first refresh
  /// and persisted on every change so the strike/backoff cycle survives
  /// process restarts — without persistence every launch re-emitted up to
  /// two full warning stacks per permanently-failing account (GlitchTip
  /// issue 3658: a Kimi account out of balance answered HTTP 429 forever
  /// and produced 173 warning events).
  final Map<String, _UsageFetchFailure> _failures =
      <String, _UsageFetchFailure>{};
  bool _failuresHydrated = false;

  static const int _maxWarningStacks = 2;
  static const Duration _minBackoff = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(minutes: 15);

  @override
  ProviderUsageSummary build() {
    _storage = ProviderUsageStorage();
    _kimiApi = KimiUsageApi();
    _miniMaxApi = MiniMaxUsageApi();
    _zaiApi = ZaiUsageApi();
    _grokApi = GrokUsageApi();
    _qwenApi = QwenUsageApi();
    ref.onDispose(_failures.clear);
    return const ProviderUsageSummary();
  }

  /// Loads the persisted strike map once per notifier lifetime.
  Future<void> _hydrateFailures() async {
    if (_failuresHydrated) return;
    _failuresHydrated = true;
    final persisted = await _storage.readFailureState();
    for (final entry in persisted.entries) {
      _failures[entry.key] ??= _UsageFetchFailure.fromPersisted(entry.value);
    }
  }

  /// Persists the strike map. Fire-and-forget — losing a write only costs
  /// one extra warning stack on the next launch.
  void _persistFailures() {
    unawaited(
      _storage.writeFailureState({
        for (final entry in _failures.entries)
          entry.key: entry.value.toPersisted(),
      }),
    );
  }

  /// Load accounts from secure storage without fetching usage.
  Future<void> loadAccounts() async {
    final accounts = await _storage.getAccounts();
    final usages = accounts
        .map(
          (a) => ProviderUsage(
            accountId: a.id,
            type: a.type,
            accountName: a.name,
            windows: const <ProviderUsageWindow>[],
          ),
        )
        .toList();
    state = state.copyWith(usages: usages, globalError: null);
  }

  /// Fetch usage for all configured accounts.
  ///
  /// Each account is fetched independently so that one failing provider does
  /// not hide results from the others.
  Future<void> refreshUsage() async {
    await _hydrateFailures();
    final accounts = await _storage.getAccounts();
    if (accounts.isEmpty) {
      state = state.copyWith(usages: const <ProviderUsage>[], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, globalError: null);

    final results = await Future.wait(
      accounts.map((account) => _fetchAccountUsage(account)),
    );

    if (!ref.mounted) return;

    state = state.copyWith(
      usages: results,
      isLoading: false,
      globalError: null,
    );
  }

  Future<ProviderUsage> _fetchAccountUsage(ProviderAccount account) async {
    final failure = _failures[account.id];
    if (failure != null && !failure.canRetry(DateTime.now())) {
      // Still within backoff — return the sticky error without hitting the
      // network or emitting another WARN stack.
      return ProviderUsage(
        accountId: account.id,
        type: account.type,
        accountName: account.name,
        windows: const <ProviderUsageWindow>[],
        error: failure.lastError,
      );
    }

    // Only attach the raw provider payload when the user has opted into
    // developer mode — otherwise `extra` stays empty so production users never
    // see the debug section in the card.
    final includeDebug = ref.read(
      settingsNotifierProvider.select((s) => s.developerModeEnabled),
    );
    try {
      // Await inside the try so async failures (e.g. a 401
      // ProviderUsageApiException) are caught here instead of escaping as an
      // unhandled async error to PlatformDispatcher.onError.
      final usage = await account.credentials.when(
        kimi: (c) => _kimiApi.getUsage(
          apiKey: c.apiKey,
          baseUrl: c.baseUrl,
          accountId: account.id,
          accountName: account.name,
          includeDebugPayload: includeDebug,
        ),
        miniMax: (c) => _miniMaxApi.getUsage(
          apiKey: c.apiKey.isNotEmpty ? c.apiKey : c.cookie,
          accountId: account.id,
          accountName: account.name,
          includeDebugPayload: includeDebug,
        ),
        zai: (c) => _zaiApi.getUsage(
          apiKey: c.apiKey,
          baseUrl: c.baseUrl,
          accountId: account.id,
          accountName: account.name,
          includeDebugPayload: includeDebug,
        ),
        grok: (c) => _grokApi.getUsage(
          accessToken: c.accessToken,
          baseUrl: c.baseUrl,
          accountId: account.id,
          accountName: account.name,
          includeDebugPayload: includeDebug,
        ),
        qwen: (c) => _qwenApi.getUsage(
          apiKey: c.apiKey,
          baseUrl: c.baseUrl,
          accountId: account.id,
          accountName: account.name,
          includeDebugPayload: includeDebug,
        ),
      );
      _failures.remove(account.id);
      if (failure != null) _persistFailures();
      return usage;
    } catch (e, stack) {
      final next = (failure ?? _UsageFetchFailure.empty()).next(e.toString());
      _failures[account.id] = next;
      _persistFailures();
      final label = '${account.type.name}/${account.id}';
      if (next.consecutiveFailures <= _maxWarningStacks) {
        logger.warning('Failed to fetch usage for $label', e, stack);
      } else {
        // Known-bad accounts poll every refresh; after two stacks demote to
        // info so Loki stays readable. UI still surfaces [ProviderUsage.error].
        logger.info(
          'Failed to fetch usage for $label '
          '(strike=${next.consecutiveFailures}, '
          'backoff=${next.backoff.inSeconds}s): $e',
        );
      }
      return ProviderUsage(
        accountId: account.id,
        type: account.type,
        accountName: account.name,
        windows: const <ProviderUsageWindow>[],
        error: e.toString(),
      );
    }
  }

  /// Adds a new provider account and persists it securely.
  ///
  /// [name] is the optional display label. An empty or whitespace-only name is
  /// stored as `null` so the card falls back to showing the vendor name only.
  Future<bool> addAccount({
    required ProviderUsageType type,
    required ProviderCredentials credentials,
    String? name,
  }) async {
    final id = const Uuid().v4();
    final trimmed = name?.trim();
    final account = ProviderAccount(
      id: id,
      type: type,
      name: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      credentials: credentials,
    );

    final saved = await _storage.saveAccount(account);
    if (!saved) return false;

    await loadAccounts();
    // Fire-and-forget refresh: guard so a provider auth failure (e.g. 401)
    // never escapes as an unhandled async error.
    unawaited(
      refreshUsage().catchError(
        (Object e, StackTrace stack) => logger.warning(
          'Background provider usage refresh failed',
          e,
          stack,
        ),
      ),
    );
    return true;
  }

  /// Renames an existing account.
  ///
  /// [name] follows the same empty-as-null semantics as [addAccount]: pass
  /// `null` or an empty/whitespace-only string to clear the custom label so
  /// the card shows the vendor name only.
  Future<bool> renameAccount(String accountId, String? name) async {
    final accounts = await _storage.getAccounts();
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;

    final trimmed = name?.trim();
    final updatedAccount = accounts[index].copyWith(
      name: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
    final saved = await _storage.saveAccount(updatedAccount);
    if (!saved) return false;

    // Mirror the rename into the in-memory usage rows so the card updates
    // immediately without waiting for a usage refresh.
    final updatedUsages = state.usages
        .map(
          (u) => u.accountId == accountId
              ? u.copyWith(accountName: updatedAccount.name)
              : u,
        )
        .toList();
    state = state.copyWith(usages: updatedUsages);
    return true;
  }

  /// Removes an account and clears its stored credentials.
  Future<bool> removeAccount(String accountId) async {
    final deleted = await _storage.deleteAccount(accountId);
    if (!deleted) return false;

    _failures.remove(accountId);
    _persistFailures();
    await loadAccounts();
    state = state.copyWith(
      usages: state.usages.where((u) => u.accountId != accountId).toList(),
    );
    return true;
  }
}

/// Tracks consecutive usage-fetch failures for a single provider account.
class _UsageFetchFailure {
  const _UsageFetchFailure({
    required this.consecutiveFailures,
    required this.lastError,
    required this.nextRetryAt,
    required this.backoff,
  });

  factory _UsageFetchFailure.empty() => _UsageFetchFailure(
    consecutiveFailures: 0,
    lastError: '',
    nextRetryAt: DateTime.fromMillisecondsSinceEpoch(0),
    backoff: ProviderUsageNotifier._minBackoff,
  );

  final int consecutiveFailures;
  final String lastError;
  final DateTime nextRetryAt;
  final Duration backoff;

  bool canRetry(DateTime now) => !now.isBefore(nextRetryAt);

  _UsageFetchFailure next(String error) {
    final nextBackoff = consecutiveFailures == 0
        ? ProviderUsageNotifier._minBackoff
        : Duration(
            microseconds:
                (backoff.inMicroseconds * 2).clamp(
                  ProviderUsageNotifier._minBackoff.inMicroseconds,
                  ProviderUsageNotifier._maxBackoff.inMicroseconds,
                ),
          );
    return _UsageFetchFailure(
      consecutiveFailures: consecutiveFailures + 1,
      lastError: error,
      nextRetryAt: DateTime.now().add(nextBackoff),
      backoff: nextBackoff,
    );
  }

  /// Plain-map shape written to [ProviderUsageStorage.writeFailureState].
  Map<String, dynamic> toPersisted() => <String, dynamic>{
    'failures': consecutiveFailures,
    'error': lastError,
    'nextRetryAtMs': nextRetryAt.millisecondsSinceEpoch,
    'backoffUs': backoff.inMicroseconds,
  };

  /// Restores a strike persisted by an earlier process. Tolerant of missing
  /// fields: anything unread resets to the empty-strike defaults.
  factory _UsageFetchFailure.fromPersisted(Map<String, dynamic> json) {
    final failures = json['failures'];
    final nextRetryAtMs = json['nextRetryAtMs'];
    final backoffUs = json['backoffUs'];
    return _UsageFetchFailure(
      consecutiveFailures:
          failures is int && failures > 0 ? failures : 0,
      lastError: json['error'] is String ? json['error'] as String : '',
      nextRetryAt: nextRetryAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(nextRetryAtMs)
          : DateTime.fromMillisecondsSinceEpoch(0),
      backoff: backoffUs is int && backoffUs > 0
          ? Duration(microseconds: backoffUs)
          : ProviderUsageNotifier._minBackoff,
    );
  }
}

/// Provider for third-party LLM provider usage state.
final providerUsageNotifierProvider =
    NotifierProvider<ProviderUsageNotifier, ProviderUsageSummary>(
      ProviderUsageNotifier.new,
    );
