{ pkgs, ... }:

{
  imports = [
    ./git.nix
    ./shell.nix
    ./ssh.nix
    ./zellij.nix
  ];

  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.11";

  home.file."Sync/.keep".text = "";
  home.file."Sync/llm-wiki/.keep".text = "";
  home.file."Repos/.keep".text = "";

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
}
