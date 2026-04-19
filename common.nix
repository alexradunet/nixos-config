{ config, pkgs, llm-agents, ... }:

let
  piPkg = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
in
{
  environment.systemPackages = with pkgs; [
    git
    neovim
    htop
    wget
    curl
    zellij
    piPkg
  ];

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  programs.zsh.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
};
}