{...}: {
  services.displayManager.sddm = {
    enable = true;
    # Use the native Wayland compositor instead of X11 for the greeter.
    # Required for Plasma 6 HDR / variable refresh rate support at login.
    wayland.enable = true;
  };
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
