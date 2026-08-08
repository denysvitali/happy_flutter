import '../types/remote_feature_failure.dart';
import 'app_localizations.dart';

extension RemoteFeatureFailureLocalization on RemoteFeatureFailureKind? {
  String localizedRemoteFeatureFailure(AppLocalizations l10n) => switch (this) {
    RemoteFeatureFailureKind.offline => l10n.remoteFeatureErrorOffline,
    RemoteFeatureFailureKind.unsupported => l10n.remoteFeatureErrorUnsupported,
    RemoteFeatureFailureKind.transient => l10n.remoteFeatureErrorTemporary,
    RemoteFeatureFailureKind.rejected => l10n.remoteFeatureErrorRejected,
    RemoteFeatureFailureKind.unknown || null => l10n.remoteFeatureErrorUnknown,
  };
}
