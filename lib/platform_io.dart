import 'dart:ffi' show Abi, DynamicLibrary, DynamicLibraryExtension, IntPtr;
import 'dart:io' show Platform, ProcessInfo;

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isLinux => Platform.isLinux;

String get linuxArchitecture => switch (Abi.current()) {
  Abi.linuxX64 => 'x64',
  Abi.linuxArm64 => 'arm64',
  _ => 'unknown',
};

/// Resident set size of this process in bytes, or 0 when unavailable.
int get currentRssBytes {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    // Some platforms (or restricted sandboxes) do not expose RSS.
    return 0;
  }
}

// POSIX clock() counts CPU consumed by all process threads, not wall time.
// These platforms define CLOCKS_PER_SEC as 1,000,000. Windows clock() has
// different semantics, so leave it unavailable rather than reporting wall time.
final int Function()? _processClock = _resolveProcessClock();

int Function()? _resolveProcessClock() {
  if (!(Platform.isLinux ||
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS)) {
    return null;
  }
  try {
    return DynamicLibrary.process()
        .lookupFunction<IntPtr Function(), int Function()>('clock');
  } catch (_) {
    return null;
  }
}

/// Cumulative process CPU time, or null when the OS cannot supply it.
Duration? get currentProcessCpuTime {
  final ticks = _processClock?.call();
  return ticks == null || ticks < 0 ? null : Duration(microseconds: ticks);
}
