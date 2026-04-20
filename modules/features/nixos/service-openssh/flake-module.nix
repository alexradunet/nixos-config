{...}: {
  flake.nixosModules.service-openssh = import ./module.nix;
}
