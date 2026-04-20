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
          nixpkgs.overlays = [config.flake.overlays.default];
          networking.hostName = "evo-nixos";
          system.stateVersion = "25.11";
        }
        ../../hosts/evo-nixos/hardware-configuration.nix
        config.flake.nixosModules.profile-desktop-workstation
        config.flake.nixosModules.profile-gaming-nvidia
        ../../hosts/evo-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-host-evo-nixos
          ];
        }
      ]
      ++ lib.optional (builtins.pathExists ../../hosts/evo-nixos/wireguard.private.nix) ../../hosts/evo-nixos/wireguard.private.nix;
  };
}
