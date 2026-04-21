{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.kate
    kdePackages.dolphin
    wezterm
    kdePackages.plasma-nm
    netbird-ui
    vlc
    vscodium
    obsidian
  ];
}
