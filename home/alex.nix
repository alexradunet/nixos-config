{...}: {
  # Shared Home Manager entrypoint for alex.
  # Host-specific Home Manager additions live under ./hosts.
  imports = [
    ./git.nix
    ./packages.nix
    ./paths.nix
    ./pi
    ./shell.nix
    ./ssh.nix
    ./zellij.nix
  ];

  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.11";

  # Let Home Manager manage its own activation and files.
  programs.home-manager.enable = true;
}
