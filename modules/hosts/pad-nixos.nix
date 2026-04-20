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
        config.flake.nixosModules.sops
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.laptop
        config.flake.nixosModules.users
        config.flake.nixosModules.host-efi-systemd-boot
        config.flake.nixosModules.host-unfree
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-wireguard
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-fail2ban
        config.flake.nixosModules.service-syncthing
        ../../hosts/pad-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.host-pad-nixos
          ];
        }
      ]
      ++ lib.optional (builtins.pathExists ../../hosts/pad-nixos/wireguard.private.nix) ../../hosts/pad-nixos/wireguard.private.nix;
  };
}
