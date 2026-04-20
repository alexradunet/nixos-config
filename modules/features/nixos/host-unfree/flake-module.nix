{...}: {
  flake.nixosModules.host-unfree = import ./module.nix;
}
