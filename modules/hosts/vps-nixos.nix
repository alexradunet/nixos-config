{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.vps-nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      {
        nixpkgs.overlays = [config.flake.overlays.default];
        networking.hostName = "vps-nixos";
        services.openssh.openFirewall = true;
        system.stateVersion = "25.11";
        nixpkgs.config.allowUnfree = true;
      }
      ../../hosts/vps-nixos/hardware-configuration.nix

      # Server base
      config.flake.nixosModules.common
      config.flake.nixosModules.users
      config.flake.nixosModules.service-openssh
      config.flake.nixosModules.service-reaction

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
