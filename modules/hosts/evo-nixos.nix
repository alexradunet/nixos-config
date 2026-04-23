{
  config,
  inputs,
  ...
}: let
  piGatewayPrivate = ../../hosts/evo-nixos/pi-gateway.private.nix;
  hasPiGatewayPrivate = builtins.pathExists piGatewayPrivate;
  piGatewayModule =
    if hasPiGatewayPrivate
    then {imports = [piGatewayPrivate];}
    else {};
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
        config.flake.nixosModules.service-pi-gateway
        ../../hosts/evo-nixos/syncthing.nix
        ../../hosts/evo-nixos/llama-cpp.nix
        ../../hosts/evo-nixos/nvidia-prime.nix
        piGatewayModule
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
