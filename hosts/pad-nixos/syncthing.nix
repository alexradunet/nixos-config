{...}: {
  services.syncthing = {
    # Nix is the source of truth — GUI changes are discarded on next activation.
    overrideDevices = true;
    overrideFolders = true;
  };

  services.syncthing.settings = {
    devices = {
      "evo-nixos" = {
        id = "L2DVUEY-6C2HAH4-NU63GHC-RNIGCVA-DRLIXSH-XFJQ5LA-S4AQLHG-3NTLEAX";
      };
    };

    folders = {
      # Unified wiki — technical + personal knowledge in one Obsidian vault.
      "wiki" = {
        path = "/home/alex/Workspace/Knowledge";
        devices = ["evo-nixos"];
      };
    };
  };
}
