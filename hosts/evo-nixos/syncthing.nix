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
      # Technical wiki — NixOS, PI agent, infra, architecture.
      # Visible to the smart LLM. domain: technical only.
      "nixpi-wiki" = {
        path = "/home/alex/Sync/Wiki/NixPI";
        devices = ["pad-nixos"];
      };

      # Personal wiki — journal, tasks, notes, health, plans.
      # Nazar (private GDPR-native LLM) only. Never seen by the technical LLM.
      "personal-wiki" = {
        path = "/home/alex/Sync/Wiki/Personal";
        devices = ["pad-nixos"];
      };
    };
  };
}
