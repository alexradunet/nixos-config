{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    htop
    wget
    curl
    fastfetch
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
