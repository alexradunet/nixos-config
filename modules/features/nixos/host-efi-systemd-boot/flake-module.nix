{...}: {
  flake.nixosModules.host-efi-systemd-boot = import ../../../hosts/efi-systemd-boot;
}
