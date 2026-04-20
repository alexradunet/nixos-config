{inputs, ...}: {
  flake = {
    nixosModules = {
      sops = inputs.sops-nix.nixosModules.sops;
      sops-common = import ./common.nix;
      sops-shared-common = import ./shared/common-secrets.nix;
      sops-evo-nixos = import ./hosts/evo-nixos.nix;
      sops-pad-nixos = import ./hosts/pad-nixos.nix;
      sops-vps-nixos = import ./hosts/vps-nixos.nix;
    };

    homeModules.sops = inputs.sops-nix.homeManagerModules.sops;
  };
}
