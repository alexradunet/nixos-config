{...}: {
  services.syncthing = {
    # Nix is the source of truth — GUI changes are discarded on next activation.
    overrideDevices = true;
    overrideFolders = true;
  };

  services.syncthing.settings = {
    devices = {
      "pad-nixos" = {
        id = "Y63CTTP-XXGWC34-DZVHRSU-SSS3PN3-WVEPFOS-ISZ4YEE-EC7PVRE-ILM66AR";
      };
    };

    folders = {
      # Unified wiki — technical + personal knowledge in one Obsidian vault.
      "wiki" = {
        path = "/home/alex/Wiki";
        devices = ["pad-nixos"];
      };
    };
  };
}
