{
  config,
  inputs,
  ...
}: let
  flakeConfig = config;
in {
  flake.nixosConfigurations.vps-nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        ({
          config,
          ...
        }: let
          alexHome = config.users.users.alex.home;
        in {
          nixpkgs.overlays = [flakeConfig.flake.overlays.default];
          networking.hostName = "vps-nixos";
          services.openssh.openFirewall = true;
          system.stateVersion = "25.11";
          nixpkgs.config.allowUnfree = true;

          services.wg-admin = {
            enable = true;
            stateDir = "${alexHome}/.local/state/wg-admin";
            user = "alex";
            group = "users";
            subnet = "10.77.0.0/24";
            allowedIPs = ["10.77.0.0/24"];
            dns = ["10.77.0.1"];
            ipStart = 30;
            rebuildFlake = "${alexHome}/Workspace/NixPI#${config.networking.hostName}";
          };
        })
        ../../hosts/vps-nixos/hardware-configuration.nix

        # Server base
        config.flake.nixosModules.common
        config.flake.nixosModules.users
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction

        # VPS extras
        config.flake.nixosModules.service-wg-admin

        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            # Home base
            config.flake.homeModules.git
            config.flake.homeModules.packages
            config.flake.homeModules.pi
            config.flake.homeModules.shell
            config.flake.homeModules.ssh
          ];
        }
      ];
  };
}
