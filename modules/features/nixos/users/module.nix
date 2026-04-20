{
  config,
  lib,
  pkgs,
  ...
}: {
  users.users.alex = {
    isNormalUser = true;
    description = "alex";
    extraGroups =
      ["wheel"]
      ++ lib.optionals config.networking.networkmanager.enable ["networkmanager"];
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9DHvYnz64l4/CfGR2oMyjKMwTxN4ubLTisFmVGQv0U alex@nixos-laptop"
    ];
  };
}
