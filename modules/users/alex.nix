{config, ...}: {
  flake.homeModules.alex = {
    imports = [
      config.flake.homeModules.sops
      config.flake.homeModules.git
      config.flake.homeModules.packages
      config.flake.homeModules.paths
      config.flake.homeModules.pi
      config.flake.homeModules.shell
      config.flake.homeModules.ssh
      config.flake.homeModules.zellij
    ];

    home.username = "alex";
    home.homeDirectory = "/home/alex";
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;
  };
}
