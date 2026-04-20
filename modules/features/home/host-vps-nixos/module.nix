{...}: {
  programs.zsh.shellAliases = {
    rb = "sudo nixos-rebuild switch --flake ~/nixos-config#vps-nixos";
    host = "echo vps-nixos";
    wga = "wg-admin";
  };
}
