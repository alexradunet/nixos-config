{ config, pkgs, ... }:

{
  home.username = "alex";
  home.homeDirectory = "/home/alex";

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    ripgrep
    fd
  ];

  programs.git = {
    enable = true;
    userName = "alex";
    userEmail = "dev@alexradu.net";
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      gs = "git status";
      nr = "sudo nixos-rebuild switch --flake ~/nixos-config#evo-nixos";
    };
  };

  programs.home-manager.enable = true;
}
