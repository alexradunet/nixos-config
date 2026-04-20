{
  # Copy this file to wireguard.private.nix to turn pad-nixos into a spoke.
  # Do not commit the populated private file.

  networking.wireguardHubAndSpoke = {
    enable = true;
    role = "client";

    address = "10.77.0.10/32";
    subnet = "10.77.0.0/24";
    privateKeyFile = "/var/lib/wireguard/pad-nixos.key";

    # Allow SSH over the private overlay.
    allowSshOnInterface = true;

    client = {
      publicKey = "REPLACE_ME_WITH_VPS_NIXOS_PUBLIC_KEY";
      endpoint = "vpn.example.com:51820";
      # Keep this to the overlay unless you intentionally want a full tunnel.
      allowedIPs = ["10.77.0.0/24"];
      persistentKeepalive = 25;
    };
  };
}
