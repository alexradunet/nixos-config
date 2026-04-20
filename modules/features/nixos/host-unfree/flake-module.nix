{...}: {
  flake.nixosModules.host-unfree = import ../../../hosts/unfree;
}
