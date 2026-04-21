{config, ...}: {
  flake.homeModules.profile-host-pad-nixos = {
    imports = [
      config.flake.homeModules.profile-base
      config.flake.homeModules.wezterm
      config.flake.homeModules.host-pad-nixos
    ];
  };
}
