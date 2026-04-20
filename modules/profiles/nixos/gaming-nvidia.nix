{config, ...}: {
  flake.nixosModules.profile-gaming-nvidia = {
    imports = [
      config.flake.nixosModules.role-gaming
      config.flake.nixosModules.role-nvidia
    ];
  };
}
