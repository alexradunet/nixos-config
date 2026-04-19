{...}: {
  # Graphical session
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Graphics support
  hardware.graphics.enable = true;

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Desktop programs
  programs.firefox.enable = true;
}
