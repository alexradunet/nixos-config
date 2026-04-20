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
      # Technical wiki — NixOS, PI agent, infra, architecture.
      # Visible to the smart LLM. domain: technical only.
      "nixpi-wiki" = {
        path = "/home/alex/Sync/Wiki/NixPI";
        devices = ["evo-nixos"];
      };
    };
  };
}
