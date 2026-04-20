{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) dirOf;
  inherit (lib) concatStringsSep escapeShellArg mkEnableOption mkIf mkOption types;
  cfg = config.services.wg-admin;
  renderLine = key: value: "${key}=${escapeShellArg value}";
in {
  options.services.wg-admin = {
    enable = mkEnableOption "wg-admin runtime peer registry and QR onboarding helper";

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/wg-admin";
      description = "Runtime state directory for wg-admin peer metadata and generated configs.";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "Owner user for the runtime state directory.";
    };

    group = mkOption {
      type = types.str;
      default = "root";
      description = "Owner group for the runtime state directory.";
    };

    serverEndpoint = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "vpn.example.com:51820";
      description = "Public WireGuard endpoint used in generated client configs.";
    };

    serverPublicKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "REPLACE_ME_BASE64_PUBLIC_KEY=";
      description = "Hub public key used in generated client configs.";
    };

    subnet = mkOption {
      type = types.str;
      default = "10.77.0.0/24";
      description = "Overlay subnet managed by wg-admin. The current helper supports IPv4 /24 allocation.";
    };

    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = ["10.77.0.0/24"];
      description = "AllowedIPs value written into generated client configs.";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Optional DNS servers written into generated client configs.";
    };

    persistentKeepalive = mkOption {
      type = types.int;
      default = 25;
      description = "PersistentKeepalive value written into generated client configs.";
    };

    interfaceName = mkOption {
      type = types.str;
      default = "wg0";
      description = "Logical WireGuard interface name for generated metadata.";
    };

    ipStart = mkOption {
      type = types.int;
      default = 30;
      description = "First host number to use when auto-allocating peer IPs within the /24 subnet.";
    };

    mtu = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Optional MTU written into generated client configs.";
    };

    nixPeersFile = mkOption {
      type = types.str;
      default = "${cfg.stateDir}/nix/peers.nix";
      description = "Path to the generated Nix peer inventory file written by wg-admin sync operations.";
    };

    rebuildFlake = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/home/alex/Repos/nixos-config#vps-nixos";
      description = "Optional flake reference used by `wg-admin rebuild` and the higher-level onboarding helpers.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.wg-admin];

    environment.etc."wg-admin/config.env".text = concatStringsSep "\n" (
      [
        (renderLine "WG_ADMIN_HOME" cfg.stateDir)
        (renderLine "WG_ADMIN_SUBNET" cfg.subnet)
        (renderLine "WG_ADMIN_ALLOWED_IPS" (concatStringsSep "," cfg.allowedIPs))
        (renderLine "WG_ADMIN_DNS" (concatStringsSep "," cfg.dns))
        (renderLine "WG_ADMIN_PERSISTENT_KEEPALIVE" (toString cfg.persistentKeepalive))
        (renderLine "WG_ADMIN_INTERFACE" cfg.interfaceName)
        (renderLine "WG_ADMIN_IP_START" (toString cfg.ipStart))
        (renderLine "WG_ADMIN_NIX_PEERS_FILE" cfg.nixPeersFile)
      ]
      ++ lib.optionals (cfg.serverEndpoint != null) [(renderLine "WG_ADMIN_SERVER_ENDPOINT" cfg.serverEndpoint)]
      ++ lib.optionals (cfg.serverPublicKey != null) [(renderLine "WG_ADMIN_SERVER_PUBLIC_KEY" cfg.serverPublicKey)]
      ++ lib.optionals (cfg.rebuildFlake != null) [(renderLine "WG_ADMIN_REBUILD_FLAKE" cfg.rebuildFlake)]
      ++ lib.optionals (cfg.mtu != null) [(renderLine "WG_ADMIN_MTU" (toString cfg.mtu))]
    );

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0700 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/peers 0700 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/generated 0700 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/archive 0700 ${cfg.user} ${cfg.group} -"
      "d ${dirOf cfg.nixPeersFile} 0700 ${cfg.user} ${cfg.group} -"
    ];
  };
}
