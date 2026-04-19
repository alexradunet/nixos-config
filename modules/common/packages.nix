{ pkgs, ... }:

let
  piPkg = pkgs.callPackage ../../pkgs/pi { };
in
{
  environment.systemPackages = with pkgs; [
    git
    neovim
    htop
    wget
    curl
    zellij
    piPkg
  ];
}
