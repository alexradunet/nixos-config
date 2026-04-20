{
  description = "My NixOS configurations";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qmd = {
      url = "github:tobi/qmd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        ./modules/core/flake-module.nix
        ./modules/packages/flake-module.nix
        ./modules/checks/flake-module.nix
        ./modules/secrets/flake-module.nix

        ./modules/features/nixos/common/flake-module.nix
        ./modules/features/nixos/desktop/flake-module.nix
        ./modules/features/nixos/laptop/flake-module.nix
        ./modules/features/nixos/users/flake-module.nix
        ./modules/features/nixos/role-gaming/flake-module.nix
        ./modules/features/nixos/role-nvidia/flake-module.nix
        ./modules/features/nixos/host-efi-systemd-boot/flake-module.nix
        ./modules/features/nixos/host-unfree/flake-module.nix
        ./modules/features/nixos/service-networkmanager/flake-module.nix
        ./modules/features/nixos/service-openssh/flake-module.nix
        ./modules/features/nixos/service-reaction/flake-module.nix
        ./modules/features/nixos/service-syncthing/flake-module.nix
        ./modules/features/nixos/service-wireguard/flake-module.nix
        ./modules/features/nixos/service-wg-admin/flake-module.nix
        ./modules/features/nixos/service-netbird/flake-module.nix
        ./modules/features/nixos/service-llama-cpp/flake-module.nix

        ./modules/features/home/git/flake-module.nix
        ./modules/features/home/packages/flake-module.nix
        ./modules/features/home/paths/flake-module.nix
        ./modules/features/home/pi/flake-module.nix
        ./modules/features/home/shell/flake-module.nix
        ./modules/features/home/ssh/flake-module.nix
        ./modules/features/home/zellij/flake-module.nix
        ./modules/features/home/host-evo-nixos/flake-module.nix
        ./modules/features/home/host-pad-nixos/flake-module.nix
        ./modules/features/home/host-vps-nixos/flake-module.nix

        ./modules/profiles/nixos/desktop-workstation.nix
        ./modules/profiles/nixos/laptop-workstation.nix
        ./modules/profiles/nixos/server-base.nix
        ./modules/profiles/nixos/gaming-nvidia.nix
        ./modules/profiles/home/base.nix
        ./modules/profiles/home/host-evo-nixos.nix
        ./modules/profiles/home/host-pad-nixos.nix
        ./modules/profiles/home/host-vps-nixos.nix

        ./modules/users/alex.nix
        ./modules/hosts/evo-nixos.nix
        ./modules/hosts/pad-nixos.nix
        ./modules/hosts/vps-nixos.nix
      ];
    };
}
