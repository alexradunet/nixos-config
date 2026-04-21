{config, ...}: let
  autoPeersFile = config.services.wg-admin.nixPeersFile;
  autoPeers =
    if builtins.pathExists autoPeersFile
    then import autoPeersFile
    else [];

  # Optional manual peers that should stay in Nix even if wg-admin regenerates
  # the runtime peer inventory. Most day-to-day onboarding should use wg-admin.
  manualPeers = [];
in {
  # Copy this file to wireguard.private.nix to turn vps-nixos into the canonical
  # WireGuard hub. Do not commit the populated private file.

  networking.wireguardHubAndSpoke = {
    enable = true;
    role = "hub";

    address = "10.77.0.1/24";
    subnet = "10.77.0.0/24";
    privateKeyFile = "/var/lib/wireguard/vps-nixos.key";
    listenPort = 51820;

    # The hub accepts inbound UDP and can expose SSH only via wg0.
    openFirewall = true;
    allowSshOnInterface = true;

    hubPeers = manualPeers ++ autoPeers;
  };

  services.wg-admin = {
    serverEndpoint = "vpn.example.com:51820";
    serverPublicKey = "REPLACE_ME_WITH_VPS_NIXOS_PUBLIC_KEY";
  };
}
