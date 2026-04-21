{
  config,
  lib,
  pkgs,
  ...
}: let
  alexHome = "/home/alex";
  flakeRef = "${alexHome}/Workspace/NixPI#${config.networking.hostName}";
  staticUnits = [
    "sshd.service"
    "syncthing.service"
    "reaction.service"
  ];
  systemctlActions = ["start" "stop" "restart"];
  staticUnitRules = lib.flatten (map (action:
    map (unit: {
      command = "/run/current-system/sw/bin/systemctl ${action} ${unit} --no-pager";
      options = ["NOPASSWD"];
    }) staticUnits
  ) systemctlActions);
in {
  users.users.alex = {
    isNormalUser = true;
    description = "alex";
    extraGroups =
      ["wheel"]
      ++ lib.optionals config.networking.networkmanager.enable ["networkmanager"];
    shell = pkgs.bashInteractive;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9DHvYnz64l4/CfGR2oMyjKMwTxN4ubLTisFmVGQv0U alex@nixos-laptop"
    ];
  };

  security.sudo.extraRules = [
    {
      users = ["alex"];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild switch --flake ${flakeRef}";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild switch --rollback";
          options = ["NOPASSWD"];
        }
      ] ++ staticUnitRules ++ [
        {
          command = "/run/current-system/sw/bin/systemctl start nixpi-*.service --no-pager";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop nixpi-*.service --no-pager";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart nixpi-*.service --no-pager";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
