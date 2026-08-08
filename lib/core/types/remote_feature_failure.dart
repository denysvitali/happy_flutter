/// Stable UI-facing categories for failures returned by optional daemon
/// features. Raw daemon prose remains available for diagnostics, but is never
/// used as user-visible copy.
enum RemoteFeatureFailureKind {
  offline,
  unsupported,
  transient,
  rejected,
  unknown,
}
