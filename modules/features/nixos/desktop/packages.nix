{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages =
    (with pkgs; [
      kdePackages.kate
      kdePackages.dolphin
      wezterm
      kdePackages.plasma-nm
      netbird-ui
      vlc
      vscodium
    ])
    ++ lib.optionals (config.nixpkgs.config.allowUnfree or false) [
      pkgs.obsidian
    ];
}
