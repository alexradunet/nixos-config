{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
  };

  outputs = { self, nixpkgs, home-manager, llm-agents, ... }:
  let
    # Shared host constructor:
    # - system module path under ./hosts
    # - shared Home Manager config in ./home/alex.nix
    # - per-host Home Manager extension module
    mkHost =
      path: homeModule:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit llm-agents; };
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
    nixosConfigurations = {
      # Mini PC / desktop workstation.
      evo-nixos = mkHost ./hosts/evo-nixos ./home/hosts/evo-nixos.nix;

      # Laptop profile.
      pad-nixos = mkHost ./hosts/pad-nixos ./home/hosts/pad-nixos.nix;
    };
  };
}
