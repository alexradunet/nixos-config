{
  config,
  inputs,
  lib,
  ...
}: let
  wireguardPrivate = ../../hosts/evo-nixos/wireguard.private.nix;
  hasWireguardPrivate = builtins.pathExists wireguardPrivate;
  # Declarative gate: import the private config unconditionally when it exists.
  # The file itself uses networking.wireguardHubAndSpoke.enable = true to activate.
  # When the file is absent, nothing happens — no builtins.pathExists in the
  # module list, no conditional import, no evaluation-time surprise.
  #
  # To enable on a fresh host: copy wireguard.private.example.nix → wireguard.private.nix
  # and fill in the secrets. The .gitignore already excludes it.
  wgModule =
    if hasWireguardPrivate
    then {imports = [wireguardPrivate];}
    else {
      networking.wireguardHubAndSpoke.enable = lib.mkDefault false;
    };
in {
  flake.nixosConfigurations.evo-nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        {
          nixpkgs.overlays = [
            config.flake.overlays.default
            inputs.llm-agents.overlays.default
          ];
          networking.hostName = "evo-nixos";
          system.stateVersion = "25.11";
        }
        ../../hosts/evo-nixos/hardware-configuration.nix
        config.flake.nixosModules.profile-desktop-workstation
        config.flake.nixosModules.profile-gaming-nvidia
        config.flake.nixosModules.service-llama-cpp
        ../../hosts/evo-nixos/syncthing.nix
        ../../hosts/evo-nixos/llama-cpp.nix
        ../../hosts/evo-nixos/nvidia-prime.nix
        wgModule
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-host-evo-nixos
          ];
        }
      ];
  };
}
