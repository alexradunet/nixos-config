{
  config,
  lib,
  pkgs,
  ...
}: let
  enabledInstances = lib.filterAttrs (_: cfg: cfg.enable) config.services.llama-servers;

  makeServerArgs = cfg:
    [
      "--host ${cfg.host}"
      "--port ${toString cfg.port}"
      "--ctx-size ${toString cfg.contextSize}"
      "--n-gpu-layers ${toString cfg.nGpuLayers}"
      "--threads ${toString cfg.threads}"
      "--parallel ${toString cfg.parallel}"
    ]
    ++ lib.optionals (cfg.hfRepo != null && cfg.hfFile != null) [
      "--hf-repo ${cfg.hfRepo}"
      "--hf-file ${cfg.hfFile}"
    ]
    ++ lib.optionals (cfg.modelPath != null) [
      "--model ${cfg.modelPath}"
    ]
    ++ cfg.extraArgs;

  makeService = name: cfg: {
    description = "llama-server (${name}): OpenAI-compatible LLM inference";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];

    environment =
      {
        HOME = "/var/lib/llama-server-${name}";
        HF_HOME = "/var/lib/llama-server-${name}/hf-cache";
        HUGGINGFACE_HUB_CACHE = "/var/lib/llama-server-${name}/hf-cache";
        # Covers CUDA runtime libs and Vulkan ICD loader on NixOS
        LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      }
      // cfg.environmentVariables;

    serviceConfig = {
      Type = "simple";
      User = "llama-server-${name}";
      Group = "llama-server-${name}";
      ExecStart = "${cfg.package}/bin/llama-server ${lib.concatStringsSep " " (makeServerArgs cfg)}";
      Restart = "on-failure";
      RestartSec = "10s";

      EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [cfg.environmentFile];

      StateDirectory = "llama-server-${name}";
      StateDirectoryMode = "0755";

      SupplementaryGroups = ["video" "render"];

      LimitNOFILE = "65536";
      LimitMEMLOCK = "infinity";
    };
  };

  instanceSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this llama-server instance";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.llama-cpp;
        defaultText = lib.literalExpression "pkgs.llama-cpp";
        description = ''
          The llama-cpp package to use. Override to select the acceleration backend:
            CUDA:   pkgs.llama-cpp.override { cudaSupport = true; }
            Vulkan: pkgs.llama-cpp.override { vulkanSupport = true; }
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Host address to bind the server to.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port to listen on.";
      };

      hfRepo = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "bartowski/gemma-4-27b-it-GGUF";
        description = "HuggingFace repository to download the model from on first start.";
      };

      hfFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "gemma-4-27b-it-Q4_K_M.gguf";
        description = "GGUF filename within the HuggingFace repository.";
      };

      modelPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/var/lib/llama-server-myinstance/models/my-model.gguf";
        description = "Absolute path to a pre-downloaded GGUF model file.";
      };

      contextSize = lib.mkOption {
        type = lib.types.int;
        default = 32768;
        description = "Context window size in tokens.";
      };

      nGpuLayers = lib.mkOption {
        type = lib.types.int;
        default = 99;
        description = ''
          Number of model layers to offload to GPU.
          Set to 99 to offload all layers, or 0 for CPU-only.
        '';
      };

      threads = lib.mkOption {
        type = lib.types.int;
        default = 8;
        description = "Number of CPU threads used for non-GPU work (e.g. MoE expert routing).";
      };

      parallel = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Number of parallel inference slots (concurrent requests).";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["--flash-attn" "--mlock"];
        description = "Additional arguments passed directly to llama-server.";
      };

      environmentVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Extra environment variables injected into the service.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression "config.sops.templates.\"llama-server-cuda-env\".path";
        description = ''
          Path to a systemd EnvironmentFile (KEY=VALUE format).
          Use this to inject secrets such as HF_TOKEN without
          putting them in the Nix store.
        '';
      };
    };
  };
in {
  options.services.llama-servers = lib.mkOption {
    type = lib.types.attrsOf instanceSubmodule;
    default = {};
    description = ''
      Named llama-server instances. Each entry generates an independent
      systemd service (llama-server-<name>), user, and state directory.

      Example with two instances on separate GPUs:
        services.llama-servers = {
          cuda   = { enable = true; port = 8080; ... };
          vulkan = { enable = true; port = 8081; ... };
        };
    '';
  };

  config = lib.mkIf (enabledInstances != {}) {
    assertions = lib.concatLists (lib.mapAttrsToList (name: cfg: [
      {
        assertion = (cfg.hfRepo != null) != (cfg.modelPath != null);
        message = "services.llama-servers.${name}: set exactly one of hfRepo+hfFile or modelPath.";
      }
      {
        assertion = cfg.hfRepo == null || cfg.hfFile != null;
        message = "services.llama-servers.${name}: hfFile must be set when hfRepo is set.";
      }
    ]) enabledInstances);

    users.users = lib.mapAttrs' (name: _:
      lib.nameValuePair "llama-server-${name}" {
        isSystemUser = true;
        group = "llama-server-${name}";
        home = "/var/lib/llama-server-${name}";
        createHome = false;
        description = "llama-server-${name} service user";
      })
    enabledInstances;

    users.groups = lib.mapAttrs' (name: _:
      lib.nameValuePair "llama-server-${name}" {})
    enabledInstances;

    systemd.services = lib.mapAttrs' (name: cfg:
      lib.nameValuePair "llama-server-${name}" (makeService name cfg))
    enabledInstances;
  };
}
