{config, ...}: {
  flake.homeModules.profile-host-pad-nixos = {
    imports = [
      config.flake.homeModules.profile-base
      config.flake.homeModules.ghostty
      config.flake.homeModules.tmux
      config.flake.homeModules.host-pad-nixos
    ];
  };
}
