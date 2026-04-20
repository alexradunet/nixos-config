{...}: {
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

      # Personal wiki — journal, tasks, notes, health, plans.
      # Nazar (private GDPR-native LLM) only. Never seen by the technical LLM.
      "personal-wiki" = {
        path = "/home/alex/Sync/Wiki/Personal";
        devices = ["evo-nixos"];
      };
    };
  };
}
