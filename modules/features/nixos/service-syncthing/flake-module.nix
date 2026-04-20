{...}: {
  flake.nixosModules.service-syncthing = import ../../../services/syncthing;
}
