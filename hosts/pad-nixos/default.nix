{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/desktop
    ../../modules/laptop
    ../../modules/users
    ../../modules/hosts/efi-systemd-boot
    ../../modules/hosts/unfree
    ../../modules/services/networkmanager
    ../../modules/services/openssh
    ../../modules/services/syncthing
    ./syncthing.nix
  ];

  networking.hostName = "pad-nixos";



  system.stateVersion = "25.11";
}
