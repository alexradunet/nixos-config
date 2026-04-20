{...}: {
  flake.nixosModules.service-fail2ban = import ./module.nix;
}
