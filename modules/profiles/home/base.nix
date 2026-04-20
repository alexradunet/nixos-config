{config, ...}: {
  flake.homeModules.profile-base = {
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
  };
}
