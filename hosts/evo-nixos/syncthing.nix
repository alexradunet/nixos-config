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
          id = "Y63CTTP-XXGWC34-DZVHRSU-SSS3PN3-WVEPFOS-ISZ4YEE-EC7PVRE-ILM66AR";
        };
      };

      folders = {
        "sync" = {
          path = "/home/alex/Sync";
          devices = [ "pad-nixos" ];
        };
      };
    };
  };
}