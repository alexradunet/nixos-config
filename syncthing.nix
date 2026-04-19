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
        "pad-nixos" = {
          id = "PUT-LAPTOP-DEVICE-ID-HERE";
        };
      };

      folders = {
        "nixos-config" = {
          path = "/home/alex/nixos-config";
          devices = [ "pad-nixos" ];
        };
      };
    };
  };
}