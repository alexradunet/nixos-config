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
      ../../modules/services/wg-admin
    ]
    ++ lib.optional (builtins.pathExists ./wireguard.private.nix) ./wireguard.private.nix;

  networking.hostName = "vps-nixos";

  # The shared users module expects the networkmanager group to exist.
  users.groups.networkmanager = {};

  # Keep SSH reachable primarily through the overlay once WireGuard is enabled.
  services.openssh.openFirewall = true;

  services.wg-admin = {
    enable = true;
    stateDir = "/home/alex/.local/state/wg-admin";
    user = "alex";
    group = "users";
    subnet = "10.77.0.0/24";
    allowedIPs = ["10.77.0.0/24"];
    dns = ["10.77.0.1"];
    ipStart = 30;
  };

  system.stateVersion = "25.11";
}
