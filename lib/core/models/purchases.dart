import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchases.freezed.dart';
part 'purchases.g.dart';

/// Purchases model
/// Tracks active subscriptions and entitlements
@freezed
abstract class Purchases with _$Purchases {
  const factory Purchases({
    @Default(<String>[]) List<String> activeSubscriptions,
    @Default(<String, bool>{}) Map<String, bool> entitlements,
  }) = _Purchases;

  const Purchases._();

  factory Purchases.fromJson(Map<String, dynamic> json) =>
      _$PurchasesFromJson(json);

  /// Default purchases
  static const defaults = Purchases();

  /// Parse purchases with fallback to defaults
  static Purchases parse(dynamic purchases) {
    if (purchases is Map<String, dynamic>) {
      return Purchases.fromJson(purchases);
    }
    return Purchases.defaults;
  }

  /// Check if a specific entitlement is active
  bool hasEntitlement(String entitlementId) {
    return entitlements[entitlementId] ?? false;
  }

  /// Check if user has an active subscription
  bool get hasActiveSubscription => activeSubscriptions.isNotEmpty;
}
