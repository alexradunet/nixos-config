{ pkgs, llm-agents, ... }:

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
}
