{inputs, ...}: {
  flake.homeModules.alex = {
    imports = [
      inputs.sops-nix.homeManagerModules.sops
      ../../home/git.nix
      ../../home/packages.nix
      ../../home/paths.nix
      ../../home/pi
      ../../home/shell.nix
      ../../home/ssh.nix
      ../../home/zellij.nix
    ];

    home.username = "alex";
    home.homeDirectory = "/home/alex";
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;
  };
}
