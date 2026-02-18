{ pkgs, ... }:

{
  packages = [
    pkgs.git
    pkgs.flutter
    pkgs.jdk21
  ];

  android.enable = false;

  env = {
    DART_SDK = "${pkgs.flutter.out}/bin/cache/dart-sdk";
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
