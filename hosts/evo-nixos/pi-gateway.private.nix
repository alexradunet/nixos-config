{
  # Local private config for the Pi WhatsApp gateway on evo-nixos.
  # This file is gitignored.
  #
  # Trusted user number: +40724417990
  # Dedicated Pi WhatsApp account to pair via QR: +40749599297

  services.pi-gateway = {
    enable = true;

    whatsapp = {
      enable = true;
      trustedNumbers = [ "+40724417990" ];
      adminNumbers = [ "+40724417990" ];
      directMessagesOnly = true;
    };
  };
}
