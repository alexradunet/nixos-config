{config, ...}: {
  flake.homeModules.profile-host-vps-nixos = {
    imports = [
      config.flake.homeModules.profile-base
      config.flake.homeModules.host-vps-nixos
    ];
  };
}
