import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/provider_usage.dart';
import 'logger_service.dart' show logger;

/// Secure storage for third-party LLM provider credentials.
///
/// Credentials are persisted with FlutterSecureStorage and cached in memory
/// for the duration of the app session to avoid repeated slow secure-storage
/// reads.
class ProviderUsageStorage {
  factory ProviderUsageStorage() => _instance;
  ProviderUsageStorage._();
  static final ProviderUsageStorage _instance = ProviderUsageStorage._();

  static const String _accountsKey = 'provider_usage_accounts';
  static const String _failuresKey = 'provider_usage_failures';

  final _secureStorage = const FlutterSecureStorage();
  List<ProviderAccount>? _cachedAccounts;

  /// Returns all configured provider accounts.
  Future<List<ProviderAccount>> getAccounts() async {
    if (_cachedAccounts != null) return _cachedAccounts!;

    try {
      final stored = await _secureStorage.read(key: _accountsKey);
      if (stored == null || stored.isEmpty) {
        _cachedAccounts = const <ProviderAccount>[];
        return _cachedAccounts!;
      }

      final decoded = jsonDecode(stored) as List<dynamic>;
      _cachedAccounts = decoded
          .whereType<Map<String, dynamic>>()
          .map(ProviderAccount.fromJson)
          .toList();
      return _cachedAccounts!;
    } catch (e, stack) {
      logger.error('Failed to load provider usage accounts', e, stack);
      _cachedAccounts = const <ProviderAccount>[];
      return _cachedAccounts!;
    }
  }

  /// Saves [accounts], replacing any previously stored list.
  Future<bool> saveAccounts(List<ProviderAccount> accounts) async {
    try {
      final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await _secureStorage.write(key: _accountsKey, value: json);
      _cachedAccounts = List<ProviderAccount>.unmodifiable(accounts);
      return true;
    } catch (e, stack) {
      logger.error('Failed to save provider usage accounts', e, stack);
      return false;
    }
  }

  /// Adds or updates a single account.
  Future<bool> saveAccount(ProviderAccount account) async {
    final accounts = await getAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    final updated = List<ProviderAccount>.from(accounts);
    if (index >= 0) {
      updated[index] = account;
    } else {
      updated.add(account);
    }
    return saveAccounts(updated);
  }

  /// Removes the account with [accountId].
  Future<bool> deleteAccount(String accountId) async {
    final accounts = await getAccounts();
    final updated = accounts.where((a) => a.id != accountId).toList();
    if (updated.length == accounts.length) return true;
    return saveAccounts(updated);
  }

  /// Clears all stored accounts and the in-memory cache.
  Future<bool> clear() async {
    try {
      await _secureStorage.delete(key: _accountsKey);
      _cachedAccounts = const <ProviderAccount>[];
      return true;
    } catch (e, stack) {
      logger.error('Failed to clear provider usage accounts', e, stack);
      return false;
    }
  }

  /// Reads the persisted per-account fetch-failure state, or an empty map
  /// when nothing is stored. Shape:
  /// `{accountId: {failures: int, error: String, nextRetryAtMs: int,
  ///   backoffUs: int}}`
  ///
  /// The strike map is persisted so an account whose provider state is
  /// permanently failing (e.g. an out-of-balance Kimi key answering 429
  /// forever) does not restart its warning/backoff cycle on every app
  /// launch — without this, each process re-emitted up to two full Sentry
  /// warning stacks per dead account (GlitchTip issue 3658, 173 events).
  Future<Map<String, Map<String, dynamic>>> readFailureState() async {
    try {
      final stored = await _secureStorage.read(key: _failuresKey);
      if (stored == null || stored.isEmpty) {
        return const <String, Map<String, dynamic>>{};
      }
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) {
        return const <String, Map<String, dynamic>>{};
      }
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (e, stack) {
      logger.error('Failed to load provider usage failure state', e, stack);
      return const <String, Map<String, dynamic>>{};
    }
  }

  /// Persists the per-account fetch-failure state.
  Future<bool> writeFailureState(
    Map<String, Map<String, dynamic>> state,
  ) async {
    try {
      if (state.isEmpty) {
        await _secureStorage.delete(key: _failuresKey);
        return true;
      }
      await _secureStorage.write(key: _failuresKey, value: jsonEncode(state));
      return true;
    } catch (e, stack) {
      logger.error('Failed to save provider usage failure state', e, stack);
      return false;
    }
  }
}
