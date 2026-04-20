{lib, ...}: let
  secretFile = ../../../secrets/pad-nixos.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.defaultSopsFile = secretFile;
  }
