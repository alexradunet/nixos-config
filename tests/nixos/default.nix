{
  pkgs,
  lib,
  config,
  inputs,
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

  mkVmHostBase = hostName: {
    networking.hostName = hostName;
    system.stateVersion = "25.11";
    virtualisation.memorySize = 4096;
    virtualisation.diskSize = 16384;
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

  evo-nixos-smoke = pkgs.testers.runNixOSTest {
    name = "evo-nixos-smoke";

    nodes.machine = {pkgs, ...}: {
      imports = [
        config.flake.nixosModules.sops
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.users
        config.flake.nixosModules.host-efi-systemd-boot
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-wireguard
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        config.flake.nixosModules.service-syncthing
        config.flake.nixosModules.service-llama-cpp
        config.flake.nixosModules.sops-common
        config.flake.nixosModules.sops-shared-common
        config.flake.nixosModules.sops-evo-nixos
        ../../hosts/evo-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          services.llama-server = {
            enable = true;
            modelPath = "/tmp/test-model.gguf";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-base
            config.flake.homeModules.wezterm
            config.flake.homeModules.host-evo-nixos
          ];
        }
        (mkVmHostBase "evo-nixos")
      ];
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("display-manager.service")
      machine.wait_for_unit("NetworkManager.service")
      machine.wait_for_unit("sshd.service")
      machine.wait_for_unit("reaction.service")
      machine.wait_for_unit("syncthing.service")

      with subtest("evo host enables expected desktop workstation stack"):
          machine.succeed("systemctl is-active display-manager.service")
          machine.succeed("systemctl is-active NetworkManager.service")
          machine.succeed("systemctl cat llama-server.service >/dev/null")

      with subtest("evo host keeps syncthing and ssh active"):
          machine.succeed("systemctl is-active syncthing.service")
          machine.succeed("systemctl is-active sshd.service")
    '';
  };

  pad-nixos-smoke = pkgs.testers.runNixOSTest {
    name = "pad-nixos-smoke";

    nodes.machine = {...}: {
      imports = [
        config.flake.nixosModules.sops
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.laptop
        config.flake.nixosModules.users
        config.flake.nixosModules.host-efi-systemd-boot
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-wireguard
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        config.flake.nixosModules.service-syncthing
        config.flake.nixosModules.sops-common
        config.flake.nixosModules.sops-shared-common
        config.flake.nixosModules.sops-pad-nixos
        ../../hosts/pad-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-host-pad-nixos
          ];
        }
        (mkVmHostBase "pad-nixos")
      ];
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("display-manager.service")
      machine.wait_for_unit("NetworkManager.service")
      machine.wait_for_unit("syncthing.service")

      with subtest("pad host enables laptop workstation stack"):
          machine.succeed("systemctl is-active display-manager.service")
          machine.succeed("systemctl is-active NetworkManager.service")
          machine.succeed("systemctl is-active syncthing.service")
          machine.succeed("systemctl cat power-profiles-daemon.service >/dev/null")
          machine.succeed("command -v powerprofilesctl >/dev/null")

      with subtest("pad host keeps expected desktop services"):
          machine.succeed("command -v firefox >/dev/null")
          machine.succeed("command -v kwriteconfig6 >/dev/null")
    '';
  };

  vps-nixos-smoke = pkgs.testers.runNixOSTest {
    name = "vps-nixos-smoke";

    nodes.machine = {pkgs, ...}: {
      imports = [
        config.flake.nixosModules.sops
        config.flake.nixosModules.common
        config.flake.nixosModules.users
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        config.flake.nixosModules.service-wireguard
        config.flake.nixosModules.sops-common
        config.flake.nixosModules.sops-shared-common
        config.flake.nixosModules.sops-vps-nixos
        config.flake.nixosModules.service-wg-admin
        inputs.home-manager.nixosModules.home-manager
        {
          services.openssh.openFirewall = true;
          services.wg-admin = {
            enable = true;
            stateDir = "/home/alex/.local/state/wg-admin";
            user = "alex";
            group = "users";
            subnet = "10.77.0.0/24";
            allowedIPs = ["10.77.0.0/24"];
            dns = ["10.77.0.1"];
            ipStart = 30;
            rebuildFlake = "/home/alex/Workspace/NixPI#vps-nixos";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-host-vps-nixos
          ];
        }
        (mkVmHostBase "vps-nixos")
      ];
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")

      with subtest("vps host enables server and wg-admin stack"):
          machine.succeed("systemctl is-active sshd.service")
          machine.succeed("command -v wg-admin >/dev/null")
          machine.succeed("test -f /etc/wg-admin/config.env")
          machine.succeed("grep -F 'WG_ADMIN_HOME=' /etc/wg-admin/config.env >/dev/null")
          machine.succeed("grep -F 'WG_ADMIN_SUBNET=' /etc/wg-admin/config.env >/dev/null")
          machine.succeed("grep -F 'WG_ADMIN_NIX_PEERS_FILE=' /etc/wg-admin/config.env >/dev/null")

      with subtest("vps host keeps reaction and user setup active"):
          machine.succeed("systemctl is-active reaction.service")
          machine.succeed("id alex")
          machine.succeed("getent passwd alex | cut -d: -f7 | grep -F 'bash'")
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

  pi-runtime-smoke = pkgs.testers.runNixOSTest {
    name = "pi-runtime-smoke";

    nodes.machine = {...}: {
      imports = [
        config.flake.nixosModules.common
        config.flake.nixosModules.users
        inputs.home-manager.nixosModules.home-manager
        {
          networking.hostName = "pi-runtime-smoke";
          system.stateVersion = "25.11";

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.profile-base
          ];
        }
      ];
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-alex.service")

      with subtest("pi agent runtime extensions and skills are installed"):
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/extensions/persona/index.ts")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/extensions/os/index.ts")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/extensions/nixpi/index.ts")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/skills/os-operations/SKILL.md")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/skills/self-evolution/SKILL.md")

      with subtest("pi runtime seed files are present"):
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/guardrails.yaml")
          machine.wait_until_succeeds("grep -F 'tool: bash' /home/alex/.pi/agent/guardrails.yaml")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/prompts/wiki.md")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/settings.json")
          machine.wait_until_succeeds("grep -F '\"qmd\"' /home/alex/.pi/agent/settings.json")

      with subtest("wiki starter seeds canonical structure"):
          machine.wait_until_succeeds("test -d /home/alex/Workspace/Knowledge/pages/home")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/pages/home/start-here.md")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/meta/registry.json")
    '';
  };
}
