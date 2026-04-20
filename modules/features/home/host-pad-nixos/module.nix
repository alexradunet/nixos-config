{...}: {
  programs.zsh.shellAliases = {
    rb = "sudo nixos-rebuild switch --flake ~/nixos-config#pad-nixos";
    host = "echo pad-nixos";
  };
}
