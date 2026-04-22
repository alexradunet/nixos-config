{
  # Copy this file to pi-gateway.private.nix to enable the Pi WhatsApp gateway on evo-nixos.
  # Do not commit the populated private file.
  #
  # Recommended first test host: evo-nixos, because it is the current interactive machine
  # and is easier to pair and validate before moving the gateway to an always-on server.
  #
  # Pairing notes:
  # - enable the service below
  # - rebuild evo-nixos
  # - watch `journalctl -u nixpi-gateway -f`
  # - when the service logs that a WhatsApp QR is ready, pair the dedicated Pi WhatsApp account
  # - after pairing, auth state persists under /var/lib/nixpi-gateway/whatsapp/auth

  services.pi-gateway = {
    enable = true;

    whatsapp = {
      enable = true;

      # Only your personal WhatsApp number should be allowed in v1.
      trustedNumbers = [
        "+40123456789"
      ];

      # Admin can stay the same as trustedNumbers in the first version.
      adminNumbers = [
        "+40123456789"
      ];

      directMessagesOnly = true;
      headless = true;

      # Defaults are already sensible, but you can override them here if needed.
      # sessionDataPath = "/var/lib/nixpi-gateway/whatsapp/auth";
      # chromiumExecutablePath = "/run/current-system/sw/bin/chromium";
    };
  };
}
