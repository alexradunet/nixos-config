{
  config,
  inputs,
  lib,
  ...
}: let
  piGatewayPrivate = ../../hosts/evo-nixos/pi-gateway.private.nix;
  hasPiGatewayPrivate = builtins.pathExists piGatewayPrivate;
  piGatewayModule =
    if hasPiGatewayPrivate
    then {imports = [piGatewayPrivate];}
    else {};

  secretsPrivate = ../../hosts/evo-nixos/secrets.private.nix;
  hasSecretsPrivate = builtins.pathExists secretsPrivate;
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
          nixpkgs.config.allowUnfree = true;
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
        }
        ../../hosts/evo-nixos/hardware-configuration.nix

        # Desktop workstation base
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.users
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        config.flake.nixosModules.service-syncthing

        # Gaming + NVIDIA
        config.flake.nixosModules.role-gaming
        config.flake.nixosModules.role-nvidia

        # evo-nixos extras
        config.flake.nixosModules.service-llama-cpp
        config.flake.nixosModules.service-pi-gateway
        ../../hosts/evo-nixos/syncthing.nix
        ../../hosts/evo-nixos/llama-cpp.nix
        ../../hosts/evo-nixos/nvidia-prime.nix
        piGatewayModule

        # ── Host-local secrets (gitignored) ───────────────────────────────
        # Declare the option so NixOS knows about it, then import values
        # from secrets.private.nix if it exists.
        {
          options.secrets = lib.mkOption {
            type = lib.types.submodule {
              options.syntheticApiKey = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Synthetic API key for web_search extension";
              };
            };
            default = {};
            description = "Host-local secrets (gitignored private files)";
          };
        }
        (if hasSecretsPrivate then {imports = [secretsPrivate];} else {})

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
            # evo-nixos extras
            config.flake.homeModules.llm-agents
            config.flake.homeModules.ghostty
            config.flake.homeModules.host-evo-nixos
          ];
        }
        # Bridge NixOS secrets into home-manager session variables
        # (must be a separate module so `config` refers to the NixOS config)
        ({config, ...}: {
          home-manager.users.alex.home.sessionVariables.SYNTHETIC_API_KEY =
            config.secrets.syntheticApiKey;
        })
      ];
  };
}
