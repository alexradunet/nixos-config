{lib, ...}: let
  secretFile = ../../../secrets/evo-nixos.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.defaultSopsFile = secretFile;
  }
