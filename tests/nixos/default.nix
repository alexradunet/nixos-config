{
  pkgs,
  lib,
  config,
  inputs,
}: let
  mkVmHostBase = hostName: {
    networking.hostName = hostName;
    system.stateVersion = "25.11";
    virtualisation.memorySize = 4096;
    virtualisation.diskSize = 16384;
  };
in {
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
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.users
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        config.flake.nixosModules.service-syncthing
        config.flake.nixosModules.service-llama-cpp
        ../../hosts/evo-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          services.llama-servers.default = {
            enable = true;
            modelPath = "/tmp/test-model.gguf";
          };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.git
            config.flake.homeModules.packages
            config.flake.homeModules.pi
            config.flake.homeModules.shell
            config.flake.homeModules.ssh
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
          machine.succeed("systemctl cat llama-server-default.service >/dev/null")

      with subtest("evo host keeps syncthing and ssh active"):
          machine.succeed("systemctl is-active syncthing.service")
          machine.succeed("systemctl is-active sshd.service")
    '';
  };

  pad-nixos-smoke = pkgs.testers.runNixOSTest {
    name = "pad-nixos-smoke";

    nodes.machine = {...}: {
      imports = [
        config.flake.nixosModules.common
        config.flake.nixosModules.desktop
        config.flake.nixosModules.laptop
        config.flake.nixosModules.users
        config.flake.nixosModules.service-networkmanager
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        config.flake.nixosModules.service-syncthing
        ../../hosts/pad-nixos/syncthing.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.git
            config.flake.homeModules.packages
            config.flake.homeModules.pi
            config.flake.homeModules.shell
            config.flake.homeModules.ssh
            config.flake.homeModules.ghostty
            config.flake.homeModules.host-pad-nixos
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
        config.flake.nixosModules.common
        config.flake.nixosModules.users
        config.flake.nixosModules.service-openssh
        config.flake.nixosModules.service-reaction
        inputs.home-manager.nixosModules.home-manager
        {
          services.openssh.openFirewall = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.alex.imports = [
            config.flake.homeModules.alex
            config.flake.homeModules.git
            config.flake.homeModules.packages
            config.flake.homeModules.pi
            config.flake.homeModules.shell
            config.flake.homeModules.ssh
          ];
        }
        (mkVmHostBase "vps-nixos")
      ];
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")

      with subtest("vps host enables server stack"):
          machine.succeed("systemctl is-active sshd.service")

      with subtest("vps host keeps reaction and user setup active"):
          machine.succeed("systemctl is-active reaction.service")
          machine.succeed("id alex")
          machine.succeed("getent passwd alex | cut -d: -f7 | grep -F 'bash'")
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
            config.flake.homeModules.git
            config.flake.homeModules.packages
            config.flake.homeModules.pi
            config.flake.homeModules.shell
            config.flake.homeModules.ssh
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
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/extensions/subagent/index.ts")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/extensions/zz-synthetic-search/index.ts")
          machine.wait_until_succeeds("grep -F 'inherit the current Pi model' /home/alex/.pi/agent/extensions/subagent/index.ts")
          machine.wait_until_succeeds("grep -F 'Synthetic' /home/alex/.pi/agent/extensions/zz-synthetic-search/index.ts")
          machine.wait_until_succeeds("grep -F 'nixpi_status' /home/alex/.pi/agent/extensions/nixpi/index.ts")
          machine.wait_until_succeeds("grep -F 'nixpi_evolution_note' /home/alex/.pi/agent/extensions/nixpi/index.ts")
          machine.wait_until_succeeds("grep -F 'update-blueprints' /home/alex/.pi/agent/extensions/nixpi/index.ts")
          machine.wait_until_succeeds("grep -F 'schedule_reboot' /home/alex/.pi/agent/extensions/os/index.ts")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/skills/os-operations/SKILL.md")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/skills/self-evolution/SKILL.md")

      with subtest("pi runtime seed files are present"):
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/guardrails.yaml")
          machine.wait_until_succeeds("grep -F 'tool: bash' /home/alex/.pi/agent/guardrails.yaml")
          machine.wait_until_succeeds("grep -F 'rm -rf /' /home/alex/.pi/agent/guardrails.yaml")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/prompts/wiki.md")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/settings.json")
          machine.wait_until_succeeds("grep -F '\"qmd\"' /home/alex/.pi/agent/settings.json")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/models.json")
          machine.wait_until_succeeds("grep -F '\"providers\"' /home/alex/.pi/agent/models.json")
          machine.wait_until_succeeds("test -f /home/alex/.pi/agent/agents/scout.md")
          machine.wait_until_succeeds("grep -F 'name: scout' /home/alex/.pi/agent/agents/scout.md")

      with subtest("wiki starter seeds canonical structure"):
          machine.wait_until_succeeds("test -d /home/alex/Workspace/Knowledge/pages/home")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/pages/home/start-here.md")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/meta/registry.json")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/pages/projects/nixpi/persona/soul.md")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/pages/projects/nixpi/persona/faculty.md")
          machine.wait_until_succeeds("test -f /home/alex/Workspace/Knowledge/pages/projects/nixpi/evolution/README.md")
    '';
  };
}
