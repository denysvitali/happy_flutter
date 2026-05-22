{ pkgs, ... }:

let
  # The CI workflow ostensibly pins Flutter 3.38.7 via subosito/flutter-action,
  # but channel:stable wins and subosito actually downloads the current stable
  # (3.44.0 at the time of writing). The project's pubspec depends on
  # sodium_libs 4.0.0, which requires Dart ^3.11.0 and Flutter >3.41.0 — so
  # the de-facto requirement is Flutter 3.41+. v3_41 (3.41.9, Dart 3.11.5)
  # is the closest available in nixpkgs.
  #
  # We use `flutterPackages` (binary engine) rather than
  # `flutterPackages-source` because the source build's wrapper injects
  # `--local-engine-host host_release` without the matching `--local-engine`
  # flag, which makes every flutter invocation abort with
  # "You must specify --local-engine if you are using --local-engine-host."
  flutter = pkgs.flutterPackages.v3_41;
in
{
  packages = [
    pkgs.git
    flutter
    pkgs.jdk21
  ];

  android.enable = false;

  env = {
    DART_SDK = "${flutter}/bin/cache/dart-sdk";
    PKG_CONFIG_PATH = "/usr/lib/pkgconfig";
  };

  enterShell = ''
    echo "Flutter version:"
    flutter --version
  '';

  enterTest = ''
    echo "Running tests"
    flutter --version 2>&1 | head -n 1
  '';
}
