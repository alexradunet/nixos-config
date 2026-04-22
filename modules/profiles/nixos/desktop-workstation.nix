{config, ...}: {
  flake.nixosModules.profile-desktop-workstation = {
    imports = [
      config.flake.nixosModules.common
      config.flake.nixosModules.desktop
      config.flake.nixosModules.users
      config.flake.nixosModules.host-efi-systemd-boot
      config.flake.nixosModules.host-unfree
      config.flake.nixosModules.service-networkmanager
      config.flake.nixosModules.service-wireguard
      config.flake.nixosModules.service-openssh
      config.flake.nixosModules.service-reaction
      config.flake.nixosModules.service-syncthing
    ];
  };
}
