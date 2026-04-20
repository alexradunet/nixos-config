{lib, ...}: let
  secretFile = ../../../secrets/vps-nixos.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.defaultSopsFile = secretFile;
  }
