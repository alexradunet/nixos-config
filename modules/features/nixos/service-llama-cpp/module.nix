{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.llama-server;

  serverArgs =
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
in {
  options.services.llama-server = {
    enable = lib.mkEnableOption "llama-server OpenAI-compatible inference server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp;
      defaultText = lib.literalExpression "pkgs.llama-cpp";
      description = ''
        The llama-cpp package to use.
        Override to add CUDA/ROCm/Vulkan support, e.g.:
          pkgs.llama-cpp.override { cudaSupport = true; }
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
      example = "/var/lib/llama-server/models/my-model.gguf";
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
      description = "Extra environment variables for the service.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "config.sops.templates.\"llama-server-env\".path";
      description = ''
        Path to a systemd EnvironmentFile (KEY=VALUE format).
        Use this to inject secrets such as HF_TOKEN without
        putting them in the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.hfRepo != null) != (cfg.modelPath != null);
        message = "services.llama-server: set exactly one of hfRepo+hfFile or modelPath.";
      }
      {
        assertion = cfg.hfRepo == null || cfg.hfFile != null;
        message = "services.llama-server: hfFile must be set when hfRepo is set.";
      }
    ];

    users.users.llama-server = {
      isSystemUser = true;
      group = "llama-server";
      home = "/var/lib/llama-server";
      createHome = false; # handled by StateDirectory
      description = "llama-server service user";
    };

    users.groups.llama-server = {};

    systemd.services.llama-server = {
      description = "llama-server: OpenAI-compatible LLM inference";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      environment =
        {
          HOME = "/var/lib/llama-server";
          # HuggingFace Hub model cache (used when --hf-repo is set)
          HF_HOME = "/var/lib/llama-server/hf-cache";
          HUGGINGFACE_HUB_CACHE = "/var/lib/llama-server/hf-cache";
          # CUDA libraries on NixOS live under /run/opengl-driver/lib
          LD_LIBRARY_PATH = "/run/opengl-driver/lib";
        }
        // cfg.environmentVariables;

      serviceConfig = {
        Type = "simple";
        User = "llama-server";
        Group = "llama-server";
        ExecStart = "${cfg.package}/bin/llama-server ${lib.concatStringsSep " " serverArgs}";
        Restart = "on-failure";
        RestartSec = "10s";

        # Secrets injected via an environment file (e.g. HF_TOKEN)
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

        # Persistent state: downloaded models, HF cache
        StateDirectory = "llama-server";
        StateDirectoryMode = "0755";

        # GPU access
        SupplementaryGroups = ["video" "render"];

        # Allow large model files and VRAM mappings
        LimitNOFILE = "65536";
        LimitMEMLOCK = "infinity";
      };
    };
  };
}
