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
}
