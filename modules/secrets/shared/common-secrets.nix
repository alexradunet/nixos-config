{lib, ...}: let
  secretFile = ../../../secrets/common.yaml;
in
  lib.mkIf (builtins.pathExists secretFile) {
    sops.secrets.github-token = {
      sopsFile = secretFile;
      key = "github/token";
      owner = "alex";
      group = "users";
      mode = "0400";
    };

    sops.secrets.cortecs-api-key = {
      sopsFile = secretFile;
      key = "cortecs/apiKey";
      owner = "alex";
      group = "users";
      mode = "0400";
    };
  }
