{
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

    hubPeers = [
      {
        name = "evo-nixos";
        publicKey = "REPLACE_ME_WITH_EVO_NIXOS_PUBLIC_KEY";
        ip = "10.77.0.20";
      }
      {
        name = "pad-nixos";
        publicKey = "REPLACE_ME_WITH_PAD_NIXOS_PUBLIC_KEY";
        ip = "10.77.0.10";
      }
    ];
  };
}
