{pkgs}: let
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
    networking.useDHCP = false;
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
      imports = [../../modules/services/wg-admin];

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

  wireguard-hub-client = pkgs.testers.runNixOSTest {
    name = "wireguard-hub-client";

    nodes = {
      hub = {pkgs, ...}:
        (mkBaseNode "192.168.1.1")
        // {
          imports = [../../modules/services/wireguard];

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
          imports = [../../modules/services/wireguard];

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
