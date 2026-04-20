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
        config.flake.nixosModules.sops
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.role-gaming
        config.flake.nixosModules.role-nvidia
        config.flake.nixosModules.users
        config.flake.nixosModules.host-efi-systemd-boot
        config.flake.nixosModules.host-unfree
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-wireguard
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-fail2ban
        config.flake.nixosModules.service-syncthing
        ../../hosts/evo-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.host-evo-nixos
          ];
        }
      ]
      ++ lib.optional (builtins.pathExists ../../hosts/evo-nixos/wireguard.private.nix) ../../hosts/evo-nixos/wireguard.private.nix;
  };
}
