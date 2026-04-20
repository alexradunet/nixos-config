{
  lib,
  writeShellApplication,
  wireguard-tools,
  qrencode,
  coreutils,
  gnugrep,
  gnused,
  gawk,
}: let
  script = builtins.readFile ./wg-admin.sh;
in
  writeShellApplication {
    name = "wg-admin";
    runtimeInputs = [wireguard-tools qrencode coreutils gnugrep gnused gawk];
    text = script;
    meta = {
      description = "Small WireGuard peer registry and QR onboarding helper";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "wg-admin";
    };
  }
