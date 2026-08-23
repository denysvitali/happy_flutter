import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/desktop_updater_models.dart';
import '../services/desktop_updater_service.dart';

export '../services/desktop_updater_models.dart'
    show
        DesktopInstallManifest,
        DesktopRemoteRelease,
        DesktopUpdateState,
        DesktopUpdateStatus;

/// Bridges [DesktopUpdaterService] into Riverpod. The service owns the
/// actual engine (timers, network, disk swap); this notifier only mirrors
/// its state and forwards user intents from the update banner.
class DesktopUpdaterNotifier extends Notifier<DesktopUpdateState> {
  @override
  DesktopUpdateState build() {
    // Shared engine survives notifier rebuilds so timers/state are not
    // reset if the provider is ever invalidated. Re-wire the listener on
    // every (re)build so engine state keeps flowing into this notifier.
    DesktopUpdaterService.shared.onStateChanged = (state) => this.state = state;
    return DesktopUpdaterService.shared.state;
  }

  DesktopUpdaterService get _service => DesktopUpdaterService.shared;

  /// Arms startup + periodic checks. Called once after first frame; safe to
  /// call repeatedly.
  void start() => _service.start();

  Future<bool> checkNow() => _service.checkForUpdates();

  Future<bool> downloadAndApply() => _service.applyUpdate();

  void restartIntoUpdatedVersion() => _service.restartIntoUpdatedVersion();

  void dismissBanner() => _service.dismissBanner();
}

final desktopUpdaterNotifierProvider =
    NotifierProvider<DesktopUpdaterNotifier, DesktopUpdateState>(
      DesktopUpdaterNotifier.new,
    );
