{ pkgs, ... }:

{
  packages = [
    pkgs.git
    pkgs.flutter3410
    pkgs.jdk21
  ];

  android.enable = false;

  env = {
    DART_SDK = "${pkgs.flutter3410.out}/bin/cache/dart-sdk";
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
