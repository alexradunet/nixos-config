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
    eza
    gh
  ];

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "alex";
    userEmail = "dev@alexradu.net";

    aliases = {
      st = "status";
      co = "checkout";
      sw = "switch";
      br = "branch";
      ci = "commit";
      lg = "log --oneline --graph --decorate --all";
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ls = "eza";
      ll = "eza -lah";
      la = "eza -a";
      gs = "git status";
      ga = "git add .";
      gc = "git commit -m";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#evo-nixos";
    };


    history = {
      size = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreAllDups = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
