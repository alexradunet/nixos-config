{
  config,
  inputs,
  lib,
  ...
}: {
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
        config.flake.nixosModules.sops-common
        config.flake.nixosModules.sops-shared-common
        config.flake.nixosModules.sops-evo-nixos
        ../../hosts/evo-nixos/syncthing.nix
        ../../hosts/evo-nixos/llama-cpp.nix
        ../../hosts/evo-nixos/nvidia-prime.nix
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
      ]
      ++ lib.optional (builtins.pathExists ../../hosts/evo-nixos/wireguard.private.nix) ../../hosts/evo-nixos/wireguard.private.nix;
  };
}
