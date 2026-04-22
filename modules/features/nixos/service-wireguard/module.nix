{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption optional types;

  cfg = config.networking.wireguardHubAndSpoke;

  hubPeers =
    map (
      peer:
        {
          inherit (peer) name publicKey;
          allowedIPs = ["${peer.ip}/32"] ++ peer.extraAllowedIPs;
        }
        // lib.optionalAttrs (peer.endpoint != null) {
          endpoint = peer.endpoint;
        }
        // lib.optionalAttrs (peer.persistentKeepalive != null) {
          persistentKeepalive = peer.persistentKeepalive;
        }
    )
    cfg.hubPeers;

  clientPeer = {
    name = cfg.client.name;
    publicKey = cfg.client.publicKey;
    allowedIPs = cfg.client.allowedIPs;
    endpoint = cfg.client.endpoint;
    persistentKeepalive = cfg.client.persistentKeepalive;
  };

  generatedPeers =
    if cfg.role == "hub"
    then hubPeers
    else [clientPeer];

  baseInterface =
    {
      ips = [cfg.address];
      privateKeyFile = cfg.privateKeyFile;
      listenPort = cfg.listenPort;
      peers = generatedPeers;
    }
    // lib.optionalAttrs (cfg.mtu != null) {
      mtu = cfg.mtu;
    };
in {
  options.networking.wireguardHubAndSpoke = {
    enable = mkEnableOption "a simple WireGuard hub-and-spoke overlay";

    role = mkOption {
      type = types.enum ["hub" "client"];
      default = "client";
      description = "Whether this machine acts as the WireGuard hub or as a client spoke.";
    };

    interfaceName = mkOption {
      type = types.str;
      default = "wg0";
      description = "WireGuard interface name.";
    };

    address = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "10.77.0.10/32";
      description = "Overlay address assigned to this host, including CIDR suffix.";
    };

    subnet = mkOption {
      type = types.str;
      default = "10.77.0.0/24";
      description = "Overlay subnet routed across the hub-and-spoke network.";
    };

    listenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "UDP listen port for the WireGuard interface.";
    };

    privateKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/var/lib/wireguard/pad-nixos.key";
      description = "Absolute path to this host's private WireGuard key file.";
    };

    privateConfigFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/etc/nixos/wireguard.private.nix";
      description = ''
        Optional path to a host-specific Nix file containing the private
        WireGuard overlay configuration (keys, endpoints, etc.).
        When non-null, this file is imported into the host's module list
        unconditionally — the file is expected to exist.
        This replaces the old builtins.pathExists conditional-import pattern.
      '';
    };

    mtu = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Optional MTU override for the WireGuard interface.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the WireGuard UDP listen port in the local firewall.";
    };

    allowSshOnInterface = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow SSH only via the WireGuard interface.";
    };

    hubPeers = mkOption {
      default = [];
      description = "Peer inventory for the hub. Each peer gets a unique /32 plus any extra routed prefixes.";
      type = types.listOf (types.submodule ({name, ...}: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
            description = "Peer name used only for readability in the generated configuration.";
          };

          publicKey = mkOption {
            type = types.str;
            example = "REPLACE_ME_BASE64_PUBLIC_KEY=";
            description = "Public WireGuard key of the spoke peer.";
          };

          ip = mkOption {
            type = types.str;
            example = "10.77.0.10";
            description = "Single overlay IP assigned to the spoke peer, without CIDR suffix.";
          };

          extraAllowedIPs = mkOption {
            type = types.listOf types.str;
            default = [];
            example = ["192.168.50.0/24"];
            description = "Additional routed prefixes that should be reachable through this spoke.";
          };

          endpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "example.com:51820";
            description = "Optional explicit endpoint for this spoke. Leave null for roaming/NATed clients.";
          };

          persistentKeepalive = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Optional keepalive interval for this peer. Usually clients send keepalives to the hub instead.";
          };
        };
      }));
    };

    client = {
      name = mkOption {
        type = types.str;
        default = "hub";
        description = "Readable name for the hub peer entry on a client.";
      };

      publicKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "REPLACE_ME_BASE64_PUBLIC_KEY=";
        description = "Public WireGuard key of the hub.";
      };

      endpoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "vpn.example.com:51820";
        description = "Public endpoint of the hub.";
      };

      allowedIPs = mkOption {
        type = types.listOf types.str;
        default = [cfg.subnet];
        description = "Routes that the client should send through the hub. Keep this to the overlay subnet for a simple private network.";
      };

      persistentKeepalive = mkOption {
        type = types.int;
        default = 25;
        description = "Keepalive interval sent by the client to keep NAT mappings alive.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.address != null;
        message = "networking.wireguardHubAndSpoke.address must be set when the overlay is enabled.";
      }
      {
        assertion = cfg.privateKeyFile != null || cfg.privateConfigFile != null;
        message = "networking.wireguardHubAndSpoke.privateKeyFile must be set when the overlay is enabled (or use privateConfigFile to provide it from an external file).";
      }
      {
        assertion = cfg.role != "client" || cfg.client.publicKey != null;
        message = "networking.wireguardHubAndSpoke.client.publicKey must be set for client hosts.";
      }
      {
        assertion = cfg.role != "client" || cfg.client.endpoint != null;
        message = "networking.wireguardHubAndSpoke.client.endpoint must be set for client hosts.";
      }
    ];

    networking.useNetworkd = lib.mkDefault true;

    networking.wireguard = {
      enable = true;
      useNetworkd = true;
      interfaces.${cfg.interfaceName} = baseInterface;
    };

    services.resolved.enable = lib.mkDefault true;

    networking.firewall.allowedUDPPorts = optional (cfg.role == "hub" || cfg.openFirewall) cfg.listenPort;
    networking.firewall.interfaces.${cfg.interfaceName}.allowedTCPPorts = optional cfg.allowSshOnInterface 22;

    boot.kernel.sysctl = mkIf (cfg.role == "hub") {
      "net.ipv4.ip_forward" = 1;
    };
  };
}
