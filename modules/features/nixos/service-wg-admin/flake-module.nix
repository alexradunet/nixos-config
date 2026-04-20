{...}: {
  flake.nixosModules.service-wg-admin = import ../../../services/wg-admin;
}
