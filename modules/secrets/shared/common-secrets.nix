{lib, ...}: let
  secretFile = ../../../secrets/common.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.secrets.cortecs-api-key = {
      sopsFile = secretFile;
      key = "cortecs/apiKey";
      owner = "alex";
      group = "users";
      mode = "0400";
    };
  }
