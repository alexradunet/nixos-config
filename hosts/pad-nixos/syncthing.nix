{ ... }:

{
  services.syncthing.settings = {
    devices = {
      "evo-nixos" = {
        id = "L2DVUEY-6C2HAH4-NU63GHC-RNIGCVA-DRLIXSH-XFJQ5LA-S4AQLHG-3NTLEAX";
      };
    };

    folders = {
      "sync" = {
        path = "/home/alex/Sync";
        devices = [ "evo-nixos" ];
      };
    };
  };
}
