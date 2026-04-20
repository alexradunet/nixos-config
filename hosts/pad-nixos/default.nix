{lib, ...}: {
  # Host definition for the laptop.
  # Shared behavior lives in ../../modules, while this file keeps
  # only machine-specific composition and identity.
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/common
      ../../modules/desktop
      ../../modules/laptop
      ../../modules/users
      ../../modules/hosts/efi-systemd-boot
      ../../modules/hosts/unfree
      ../../modules/services/networkmanager
      ../../modules/services/wireguard
      ../../modules/services/openssh
      ../../modules/services/fail2ban
      ../../modules/services/syncthing
      ./syncthing.nix
    ]
    ++ lib.optional (builtins.pathExists ./wireguard.private.nix) ./wireguard.private.nix;

  # Machine identity.
  networking.hostName = "pad-nixos";

  # Keep the installer-generated compatibility baseline unless intentionally migrated.
  system.stateVersion = "25.11";
}
