{ config, pkgs, ... }:

{
  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    tree
    unzip
    fastfetch
  ];

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "alex";
    userEmail = "dev@alexradu.net";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.bash = {
    enable = true;

    shellAliases = {
      ll = "ls -lah";
      gs = "git status";
      ga = "git add .";
      gc = "git commit -m";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#evo-nixos";
    };
  };
}
