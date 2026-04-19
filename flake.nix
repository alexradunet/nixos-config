{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    piPkg = pkgs.callPackage ./pkgs/pi { };
    piWebAccessPkg = pkgs.callPackage ./pkgs/pi-web-access { };
    piApp = {
      type = "app";
      program = "${piPkg}/bin/pi";
    };

    # Shared host constructor:
    # - system module path under ./hosts
    # - shared Home Manager config in ./home/alex.nix
    # - per-host Home Manager extension module
    mkHost =
      path: homeModule:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          path
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.alex = {
              imports = [
                ./home/alex.nix
                homeModule
              ];
            };
          }
        ];
      };
  in
  {
    packages.${system} = {
      pi = piPkg;
      pi-web-access = piWebAccessPkg;
      default = piPkg;
    };

    apps.${system} = {
      pi = piApp;
      default = piApp;
    };

    nixosConfigurations = {
      # Mini PC / desktop workstation.
      evo-nixos = mkHost ./hosts/evo-nixos ./home/hosts/evo-nixos.nix;

      # Laptop profile.
      pad-nixos = mkHost ./hosts/pad-nixos ./home/hosts/pad-nixos.nix;
    };
  };
}
