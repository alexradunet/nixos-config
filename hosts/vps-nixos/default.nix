{lib, ...}: {
  # Host definition for the canonical WireGuard VPS hub.
  # This host stays intentionally minimal: no desktop, no Syncthing,
  # just the shared base, users, SSH, fail2ban, and WireGuard.
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/common
      ../../modules/users
      ../../modules/hosts/unfree
      ../../modules/services/openssh
      ../../modules/services/fail2ban
      ../../modules/services/wireguard
    ]
    ++ lib.optional (builtins.pathExists ./wireguard.private.nix) ./wireguard.private.nix;

  networking.hostName = "vps-nixos";

  # The shared users module expects the networkmanager group to exist.
  users.groups.networkmanager = {};

  # Keep SSH reachable primarily through the overlay once WireGuard is enabled.
  services.openssh.openFirewall = true;

  system.stateVersion = "25.11";
}
