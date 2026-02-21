/// Purchases model
/// Tracks active subscriptions and entitlements
class Purchases {

  const Purchases({
    this.activeSubscriptions = const [],
    this.entitlements = const {},
  });

  factory Purchases.fromJson(Map<String, dynamic> json) {
    return Purchases(
      activeSubscriptions:
          (json['activeSubscriptions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      entitlements: (json['entitlements'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ??
          {},
    );
  }
  final List<String> activeSubscriptions;
  final Map<String, bool> entitlements;

  Purchases copyWith({
    List<String>? activeSubscriptions,
    Map<String, bool>? entitlements,
  }) {
    return Purchases(
      activeSubscriptions: activeSubscriptions != null
          ? List<String>.from(activeSubscriptions)
          : List<String>.from(this.activeSubscriptions),
      entitlements: entitlements != null
          ? Map<String, bool>.from(entitlements)
          : Map<String, bool>.from(this.entitlements),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeSubscriptions': activeSubscriptions,
      'entitlements': entitlements,
    };
  }

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
