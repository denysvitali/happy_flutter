import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_tokens.dart';

/// A thin linear progress bar shown at the top of the screen
/// when any sync operation is in progress.
class SyncProgressBar extends ConsumerWidget {
  const SyncProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateNotifierProvider);

    return AnimatedSize(
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDuration.fast,
        child: syncState.isSyncing
            ? const SizedBox(
                key: ValueKey('syncing'),
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('idle')),
      ),
    );
  }
}
