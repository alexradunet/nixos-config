{ ... }:

{
  imports = [
    ./git.nix
    ./packages.nix
    ./paths.nix
    ./shell.nix
    ./ssh.nix
    ./zellij.nix
  ];

  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
