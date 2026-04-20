{config, ...}: {
  flake.nixosModules.profile-laptop-workstation = {
    imports = [
      config.flake.nixosModules.profile-desktop-workstation
      config.flake.nixosModules.laptop
    ];
  };
}
