{lib, ...}: let
  secretFile = ../../../secrets/evo-nixos.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.defaultSopsFile = secretFile;

    sops.secrets.hf-token = {
      key = "huggingface/token";
      owner = "llama-server";
      group = "llama-server";
      mode = "0400";
    };
  }
