{
  config,
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.pad-nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        {
          nixpkgs.overlays = [config.flake.overlays.default];
          networking.hostName = "pad-nixos";
          system.stateVersion = "25.11";
        }
        ../../hosts/pad-nixos/hardware-configuration.nix
        config.flake.nixosModules.profile-laptop-workstation
        config.flake.nixosModules.sops-common
        config.flake.nixosModules.sops-shared-common
        config.flake.nixosModules.sops-pad-nixos
        ../../hosts/pad-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-host-pad-nixos
          ];
        }
      ]
      ++ lib.optional (builtins.pathExists ../../hosts/pad-nixos/wireguard.private.nix) ../../hosts/pad-nixos/wireguard.private.nix;
  };
}
