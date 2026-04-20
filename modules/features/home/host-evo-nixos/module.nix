{...}: {
  programs.zsh.shellAliases = {
    rb = "sudo nixos-rebuild switch --flake ~/nixos-config#evo-nixos";
    host = "echo evo-nixos";
  };
}
