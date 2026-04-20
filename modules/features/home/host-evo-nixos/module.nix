{...}: {
  programs.zsh.shellAliases = {
    # nh reads NH_FLAKE (set via programs.nh.flake) and auto-detects the hostname.
    rb = "nh os switch";
    rbb = "nh os boot";
    rbt = "nh os test";
    host = "echo evo-nixos";
  };
}
