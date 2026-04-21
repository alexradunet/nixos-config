{lib, ...}: let
  secretFile = ../../../secrets/evo-nixos.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.defaultSopsFile = secretFile;

    # hf-token is rendered into per-instance sops.templates in llama-cpp.nix
    # so the raw secret just needs to be decryptable by sops — no owner needed here.
    sops.secrets.hf-token = {
      key = "huggingface/token";
    };
  }
