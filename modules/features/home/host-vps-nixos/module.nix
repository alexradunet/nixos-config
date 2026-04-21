{...}: {
  programs.bash.shellAliases = {
    rb = "nh os switch";
    rbb = "nh os boot";
    rbt = "nh os test";
    host = "echo vps-nixos";
    wga = "wg-admin";
  };
}
