{inputs, ...}: {
  flake = {
    nixosModules.sops = inputs.sops-nix.nixosModules.sops;
    homeModules.sops = inputs.sops-nix.homeManagerModules.sops;
  };
}
