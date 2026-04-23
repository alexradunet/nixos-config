{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.pad-nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      {
        nixpkgs.overlays = [config.flake.overlays.default];
        networking.hostName = "pad-nixos";
        system.stateVersion = "25.11";
        nixpkgs.config.allowUnfree = true;
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
      }
      ../../hosts/pad-nixos/hardware-configuration.nix

      # Laptop workstation (desktop + laptop extras)
      config.flake.nixosModules.common
      config.flake.nixosModules.desktop
      config.flake.nixosModules.laptop
      config.flake.nixosModules.users
      config.flake.nixosModules.service-networkmanager
      config.flake.nixosModules.service-openssh
      config.flake.nixosModules.service-reaction
      config.flake.nixosModules.service-syncthing

      ../../hosts/pad-nixos/syncthing.nix

      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.users.alex.imports = [
          config.flake.homeModules.alex
          # Home base
          config.flake.homeModules.fresh
          config.flake.homeModules.git
          config.flake.homeModules.packages
          config.flake.homeModules.pi
          config.flake.homeModules.shell
          config.flake.homeModules.ssh
          # pad-nixos extras
          config.flake.homeModules.ghostty
          config.flake.homeModules.host-pad-nixos
        ];
      }
    ];
  };
}
