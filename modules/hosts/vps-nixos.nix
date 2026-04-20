{
  config,
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.vps-nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        {
          nixpkgs.overlays = [config.flake.overlays.default];
          networking.hostName = "vps-nixos";
          users.groups.networkmanager = {};
          services.openssh.openFirewall = true;
          system.stateVersion = "25.11";

          services.wg-admin = {
            enable = true;
            stateDir = "/home/alex/.local/state/wg-admin";
            user = "alex";
            group = "users";
            subnet = "10.77.0.0/24";
            allowedIPs = ["10.77.0.0/24"];
            dns = ["10.77.0.1"];
            ipStart = 30;
            rebuildFlake = "/home/alex/Repos/nixos-config#vps-nixos";
          };
        }
        ../../hosts/vps-nixos/hardware-configuration.nix
        config.flake.nixosModules.sops
        config.flake.nixosModules.common
        config.flake.nixosModules.users
        config.flake.nixosModules.host-unfree
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-fail2ban
        config.flake.nixosModules.service-wireguard
        config.flake.nixosModules.service-wg-admin
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.host-vps-nixos
          ];
        }
      ]
      ++ lib.optional (builtins.pathExists ../../hosts/vps-nixos/wireguard.private.nix) ../../hosts/vps-nixos/wireguard.private.nix;
  };
}
