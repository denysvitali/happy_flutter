{ pkgs, ... }:

{
  # https://devenv.sh/packages/
  packages = [
    pkgs.git
  ];

  # Android SDK and Flutter integration
  android = {
    enable = true;
    flutter.enable = true;
  };

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.dev.exec = "${lib.getExe pkgs.watchexec} -n -- ls -la";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/

  # https://devenv.sh/basics/
  enterShell = ''
    echo "Flutter version:"
    flutter --version
    echo ""
    echo "Android SDK location: $ANDROID_HOME"
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
    echo "Verifying Flutter installation:"
    flutter --version 2>&1 | head -n 1
    echo "Verifying Android SDK:"
    echo "ANDROID_HOME=$ANDROID_HOME"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
