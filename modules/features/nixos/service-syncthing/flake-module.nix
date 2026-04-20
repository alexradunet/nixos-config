{...}: {
  flake.nixosModules.service-syncthing = import ./module.nix;
}
