{config, ...}: {
  flake.nixosModules.profile-server-base = {
    imports = [
      config.flake.nixosModules.sops
      config.flake.nixosModules.common
      config.flake.nixosModules.users
      config.flake.nixosModules.host-unfree
      config.flake.nixosModules.service-openssh
      config.flake.nixosModules.service-reaction
      config.flake.nixosModules.service-wireguard
    ];
  };
}
