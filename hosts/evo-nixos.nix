{ config, pkgs, ... }:

{
  imports = [
    ../hardware-configuration.nix
    ../common.nix
    ../desktop.nix
    ../users.nix
  ];

  networking.hostName = "evo-nixos";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
