{ config, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    user = "alex";
    dataDir = "/home/alex";
    configDir = "/home/alex/.config/syncthing";
    openDefaultPorts = true;

    settings = {
      devices = {
        "evo-nixos" = {
          id = "L2DVUEY-6C2HAH4-NU63GHC-RNIGCVA-DRLIXSH-XFJQ5LA-S4AQLHG-3NTLEAX";
        };
      };

      folders = {
        "nixos-config" = {
          path = "/home/alex/nixos-config";
          devices = [ "evo-nixos" ];
        };
      };
    };
  };
}