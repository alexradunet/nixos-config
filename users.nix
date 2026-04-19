{ config, pkgs, ... }:

{
  users.users.alex = {
    isNormalUser = true;
    description = "alex";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };
}
