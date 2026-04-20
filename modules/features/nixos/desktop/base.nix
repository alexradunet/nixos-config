{...}: {
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  hardware.graphics.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  programs.firefox.enable = true;
}
