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
      kdePackages.plasma-nm
      vlc
      zed-editor
    ])
    ++ lib.optionals (config.nixpkgs.config.allowUnfree or false) [
      pkgs.obsidian
    ];
}
