{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/desktop
    ../../modules/users
    ./syncthing.nix
  ];

  networking.hostName = "evo-nixos";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
