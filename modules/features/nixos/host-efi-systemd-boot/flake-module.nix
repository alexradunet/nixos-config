{...}: {
  flake.nixosModules.host-efi-systemd-boot = import ./module.nix;
}
