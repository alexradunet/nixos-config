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
    mkHost = path: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit llm-agents; };
      modules = [
        path
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alex = import ./home/alex.nix;
        }
      ];
    };
  in
  {
    nixosConfigurations = {
      evo-nixos = mkHost ./hosts/evo-nixos;
      pad-nixos = mkHost ./hosts/pad-nixos;
    };
  };
}
