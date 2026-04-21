{
  pkgs,
  lib,
}: let
  snakeoilKeys = {
    hub = {
      privateKey = "OPuVRS2T0/AtHDp3PXkNuLQYDiqJaBEEnYe42BSnJnQ=";
      publicKey = "IujkG119YPr2cVQzJkSLYCdjpHIDjvr/qH1w1tdKswY=";
    };

    client = {
      privateKey = "uO8JVo/sanx2DOM0L9GUEtzKZ82RGkRnYgpaYc7iXmg=";
      publicKey = "Ks9yRJIi/0vYgRmn14mIOQRwkcUGBujYINbMpik2SBI=";
    };
  };

  mkBaseNode = ip: {
    virtualisation.vlans = [1];
    networking.useDHCP = lib.mkForce false;
    networking.useNetworkd = lib.mkForce true;
    networking.interfaces.eth1.ipv4.addresses = [
      {
        address = ip;
        prefixLength = 24;
      }
    ];
  };
in {
  wg-admin-basic = pkgs.testers.runNixOSTest {
    name = "wg-admin-basic";

    nodes.hub = {pkgs, ...}: {
      imports = [../../modules/features/nixos/service-wg-admin/module.nix];

      services.wg-admin = {
        enable = true;
        serverEndpoint = "vpn.example.com:51820";
        serverPublicKey = snakeoilKeys.hub.publicKey;
      };

      environment.systemPackages = [pkgs.jq];
    };

    testScript = ''
      start_all()
      hub.wait_for_unit("multi-user.target")

      with subtest("wg-admin add creates peer metadata and generated artifacts"):
          hub.succeed("wg-admin add iphone-alex")
          hub.succeed("test -f /var/lib/wg-admin/peers/iphone-alex.env")
          hub.succeed("test -f /var/lib/wg-admin/generated/iphone-alex.conf")
          hub.succeed("grep -F 'Address = 10.77.0.30/32' /var/lib/wg-admin/generated/iphone-alex.conf")
          hub.succeed("grep -F 'name = \"iphone-alex\";' /var/lib/wg-admin/nix/peers.nix")

      with subtest("qr png and mobile share page are generated"):
          hub.succeed("test -n \"$(wg-admin qr iphone-alex --png)\"")
          hub.succeed("page=$(wg-admin mobile-page iphone-alex); test -f \"$page\"; grep -F 'WireGuard onboarding: iphone-alex' \"$page\"")

      with subtest("sync-nix keeps the generated Nix inventory readable"):
          hub.succeed("wg-admin sync-nix >/tmp/peers-path")
          hub.succeed("test -f \"$(cat /tmp/peers-path)\"")
    '';
  };

  server-base-smoke = pkgs.testers.runNixOSTest {
    name = "server-base-smoke";

    nodes.machine = {pkgs, ...}: {
      imports = [
        ../../modules/features/nixos/common/module.nix
        ../../modules/features/nixos/users/module.nix
        ../../modules/features/nixos/service-openssh/module.nix
        ../../modules/features/nixos/service-reaction/module.nix
      ];

      networking.hostName = "server-smoke";
      system.stateVersion = "25.11";
      # No networking.networkmanager — the users module omits the networkmanager
      # group on hosts where NM is not enabled (our conditional extraGroups fix).
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")
      machine.wait_for_unit("reaction.service")

      with subtest("server profile enables hardened ssh"):
          machine.succeed("sshd -T | grep -F 'permitrootlogin no'")
          machine.succeed("sshd -T | grep -F 'passwordauthentication no'")

      with subtest("server profile provisions base user and shell"):
          machine.succeed("id alex")
          machine.succeed("id -nG alex | tr ' ' '\\n' | grep -Fx wheel")
          machine.succeed("getent passwd alex | cut -d: -f7 | grep -F 'bash'")

      with subtest("reaction and common system settings are active"):
          machine.succeed("systemctl is-active reaction.service")
          machine.succeed("timedatectl show -p Timezone --value | grep -Fx Europe/Bucharest")
    '';
  };

  desktop-workstation-smoke = pkgs.testers.runNixOSTest {
    name = "desktop-workstation-smoke";

    nodes.machine = {pkgs, ...}: {
      imports = [
        ../../modules/features/nixos/common/module.nix
        ../../modules/features/nixos/desktop/module.nix
        ../../modules/features/nixos/users/module.nix
        ../../modules/features/nixos/service-networkmanager/module.nix
        ../../modules/features/nixos/service-openssh/module.nix
        ../../modules/features/nixos/service-reaction/module.nix
        ../../modules/features/nixos/service-syncthing/module.nix
      ];

      networking.hostName = "desktop-smoke";
      system.stateVersion = "25.11";
      # No manual users.groups.networkmanager — the users module adds the group
      # automatically when networking.networkmanager.enable = true.
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("display-manager.service")
      machine.wait_for_unit("NetworkManager.service")
      machine.wait_for_unit("sshd.service")
      machine.wait_for_unit("reaction.service")
      machine.wait_for_unit("syncthing.service")

      with subtest("desktop profile enables graphical and audio stack"):
          machine.succeed("systemctl is-active display-manager.service")
          machine.succeed("command -v pw-cli >/dev/null")
          machine.succeed("systemctl cat bluetooth.service >/dev/null")
          machine.succeed("command -v firefox >/dev/null")

      with subtest("desktop profile keeps core workstation services up"):
          machine.succeed("systemctl is-active NetworkManager.service")
          machine.succeed("systemctl is-active sshd.service")
          machine.succeed("systemctl is-active reaction.service")
          machine.succeed("systemctl is-active syncthing.service")
    '';
  };

  laptop-workstation-smoke = pkgs.testers.runNixOSTest {
    name = "laptop-workstation-smoke";

    nodes.machine = {pkgs, ...}: {
      imports = [
        ../../modules/features/nixos/common/module.nix
        ../../modules/features/nixos/desktop/module.nix
        ../../modules/features/nixos/laptop/module.nix
        ../../modules/features/nixos/users/module.nix
        ../../modules/features/nixos/service-networkmanager/module.nix
        ../../modules/features/nixos/service-openssh/module.nix
        ../../modules/features/nixos/service-reaction/module.nix
        ../../modules/features/nixos/service-syncthing/module.nix
      ];

      networking.hostName = "laptop-smoke";
      system.stateVersion = "25.11";
      # No manual users.groups.networkmanager — added conditionally via service-networkmanager.
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("display-manager.service")
      machine.wait_for_unit("NetworkManager.service")
      machine.wait_for_unit("syncthing.service")

      with subtest("laptop profile inherits desktop stack"):
          machine.succeed("systemctl is-active display-manager.service")
          machine.succeed("systemctl is-active NetworkManager.service")
          machine.succeed("systemctl is-active syncthing.service")

      with subtest("laptop-specific power management is configured"):
          machine.succeed("systemctl cat power-profiles-daemon.service >/dev/null")
          machine.succeed("command -v powerprofilesctl >/dev/null")
    '';
  };

  wireguard-hub-client = pkgs.testers.runNixOSTest {
    name = "wireguard-hub-client";

    nodes = {
      hub = {pkgs, ...}:
        (mkBaseNode "192.168.1.1")
        // {
          imports = [../../modules/features/nixos/service-wireguard/module.nix];

          networking.wireguardHubAndSpoke = {
            enable = true;
            role = "hub";
            address = "10.77.0.1/24";
            subnet = "10.77.0.0/24";
            privateKeyFile = toString (pkgs.writeText "wg-hub-private-key" snakeoilKeys.hub.privateKey);
            listenPort = 51820;
            openFirewall = true;
            hubPeers = [
              {
                name = "client";
                publicKey = snakeoilKeys.client.publicKey;
                ip = "10.77.0.10";
              }
            ];
          };
        };

      client = {pkgs, ...}:
        (mkBaseNode "192.168.1.2")
        // {
          imports = [../../modules/features/nixos/service-wireguard/module.nix];

          networking.wireguardHubAndSpoke = {
            enable = true;
            role = "client";
            address = "10.77.0.10/32";
            subnet = "10.77.0.0/24";
            privateKeyFile = toString (pkgs.writeText "wg-client-private-key" snakeoilKeys.client.privateKey);
            client = {
              publicKey = snakeoilKeys.hub.publicKey;
              endpoint = "192.168.1.2:51820";
              allowedIPs = ["10.77.0.0/24"];
              persistentKeepalive = 25;
            };
          };
        };
    };

    testScript = ''
      start_all()
      hub.wait_for_unit("multi-user.target")
      client.wait_for_unit("multi-user.target")

      with subtest("underlay network is reachable"):
          client.succeed("ping -c 3 192.168.1.2")
          hub.succeed("ping -c 3 192.168.1.1")

      with subtest("wireguard interfaces are configured"):
          hub.wait_until_succeeds("ip addr show dev wg0 | grep -F '10.77.0.1/24'")
          client.wait_until_succeeds("ip addr show dev wg0 | grep -F '10.77.0.10/32'")
          hub.succeed("wg show wg0 | grep -F '${snakeoilKeys.client.publicKey}'")
          client.succeed("wg show wg0 | grep -F '${snakeoilKeys.hub.publicKey}'")

      with subtest("handshake is established"):
          client.wait_until_succeeds("ping -c 1 -W 1 10.77.0.1")
          client.wait_until_succeeds("wg show wg0 latest-handshakes | awk '{print $2}' | grep -v '^0$'")
          hub.wait_until_succeeds("wg show wg0 latest-handshakes | awk '{print $2}' | grep -v '^0$'")

      with subtest("overlay connectivity works both directions"):
          client.succeed("ping -c 3 10.77.0.1")
          hub.succeed("ping -c 3 10.77.0.10")
    '';
  };
}
