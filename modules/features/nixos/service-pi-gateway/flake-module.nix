{...}: {
  flake.nixosModules.service-pi-gateway = import ./module.nix;
}
