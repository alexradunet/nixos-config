{...}: {
  flake.nixosModules.service-openssh = import ../../../services/openssh;
}
