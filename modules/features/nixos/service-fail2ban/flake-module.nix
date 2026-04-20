{...}: {
  flake.nixosModules.service-fail2ban = import ../../../services/fail2ban;
}
