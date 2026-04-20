{...}: {
  flake.nixosModules.service-wireguard = import ../../../services/wireguard;
}
