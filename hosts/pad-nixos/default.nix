{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
    ../../desktop.nix
    ../../laptop.nix
    ../../users.nix
  ];

  networking.hostName = "pad-nixos";

  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
