import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/provider_usage_api.dart';
import '../models/provider_usage.dart';
import '../services/logger_service.dart' show logger;
import '../services/provider_usage_storage.dart';

/// Riverpod notifier for third-party LLM provider usage.
///
/// Holds the list of configured accounts, their latest usage, and loading
/// state. Fetching is explicit (pull-to-refresh / init) so the tab does not
/// wake the app on every sync tick.
class ProviderUsageNotifier extends Notifier<ProviderUsageSummary> {
  late final ProviderUsageStorage _storage;
  late final KimiUsageApi _kimiApi;
  late final MiniMaxUsageApi _miniMaxApi;

  @override
  ProviderUsageSummary build() {
    _storage = ProviderUsageStorage();
    _kimiApi = KimiUsageApi();
    _miniMaxApi = MiniMaxUsageApi();
    return const ProviderUsageSummary();
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
    try {
      // Await inside the try so async failures (e.g. a 401
      // ProviderUsageApiException) are caught here instead of escaping as an
      // unhandled async error to PlatformDispatcher.onError.
      return await account.credentials.when(
        kimi: (c) => _kimiApi.getUsage(
          apiKey: c.apiKey,
          accountId: account.id,
          accountName: account.name,
        ),
        miniMax: (c) => _miniMaxApi.getUsage(
          cookie: c.cookie,
          groupId: c.groupId,
          accountId: account.id,
          accountName: account.name,
        ),
      );
    } catch (e, stack) {
      logger.warning(
        'Failed to fetch usage for ${account.type.name}/${account.id}',
        e,
        stack,
      );
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
  Future<bool> addAccount({
    required ProviderUsageType type,
    required ProviderCredentials credentials,
    String? name,
  }) async {
    final id = const Uuid().v4();
    final account = ProviderAccount(
      id: id,
      type: type,
      name: name?.trim().isNotEmpty == true ? name!.trim() : _defaultName(type),
      credentials: credentials,
    );

    final saved = await _storage.saveAccount(account);
    if (!saved) return false;

    await loadAccounts();
    // Fire-and-forget refresh: guard so a provider auth failure (e.g. 401)
    // never escapes as an unhandled async error.
    unawaited(
      refreshUsage().catchError(
        (Object e, StackTrace stack) =>
            logger.warning('Background provider usage refresh failed', e, stack),
      ),
    );
    return true;
  }

  /// Removes an account and clears its stored credentials.
  Future<bool> removeAccount(String accountId) async {
    final deleted = await _storage.deleteAccount(accountId);
    if (!deleted) return false;

    await loadAccounts();
    state = state.copyWith(
      usages: state.usages.where((u) => u.accountId != accountId).toList(),
    );
    return true;
  }

  static String _defaultName(ProviderUsageType type) {
    return switch (type) {
      ProviderUsageType.kimi => 'Kimi',
      ProviderUsageType.minimax => 'MiniMax',
      ProviderUsageType.claudeCode => 'Claude Code',
      ProviderUsageType.codex => 'Codex',
    };
  }
}

/// Provider for third-party LLM provider usage state.
final providerUsageNotifierProvider =
    NotifierProvider<ProviderUsageNotifier, ProviderUsageSummary>(
  ProviderUsageNotifier.new,
);
