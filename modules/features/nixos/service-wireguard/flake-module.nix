{...}: {
  flake.nixosModules.service-wireguard = import ./module.nix;
}
