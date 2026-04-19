{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kdePackages.kate
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.plasma-nm
    vlc
    vscodium
  ];
}
