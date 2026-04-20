# llama-server configuration for evo-nixos (RTX 5060 Ti, 16 GB VRAM)
#
# Model: Gemma 4 27B-IT (MoE, ~4B active params)
#   HF:  bartowski/gemma-4-27b-it-GGUF  /  gemma-4-27b-it-Q4_K_M.gguf
#   VRAM: ~14 GB at Q4_K_M — fits comfortably in 16 GB
#   API:  http://127.0.0.1:8080/v1  (OpenAI-compatible)
#
# On first start the service downloads the model (~14 GB) from HuggingFace
# into /var/lib/llama-server/hf-cache. Subsequent starts use the cache.
#
# Monitor:
#   journalctl -u llama-server -f
#   curl http://127.0.0.1:8080/health
{config, lib, pkgs, ...}: let
  secretFile = ../../secrets/evo-nixos.yaml;
  hasSecrets = builtins.pathExists secretFile;
in {
  # Render HF_TOKEN into an EnvironmentFile that systemd loads at runtime.
  # Only active when secrets/evo-nixos.yaml is git-tracked and present.
  sops.templates."llama-server-env" = lib.mkIf hasSecrets {
    content = ''HF_TOKEN=${config.sops.placeholder."hf-token"}'';    owner = "llama-server";
    group = "llama-server";
    mode = "0400";
  };

  services.llama-server = {
    enable = true;

    # Build llama-cpp with CUDA support for the RTX 5060 Ti (sm_120 / Blackwell)
    package = pkgs.llama-cpp.override {cudaSupport = true;};

    hfRepo = "bartowski/google_gemma-4-26B-A4B-it-GGUF";
    hfFile = "google_gemma-4-26B-A4B-it-IQ4_XS.gguf"; # 14.2 GB

    # MoE model: push all layers to GPU, extra CPU threads for expert routing
    nGpuLayers = 99;
    threads = 8;

    # Vision encoder disabled — frees ~1.1 GB VRAM, allowing larger context
    # Re-enable by removing --no-mmproj when vision is needed
    contextSize = 32768;

    host = "127.0.0.1";
    port = 8080;

    environmentVariables.LLAMA_ARG_FLASH_ATTN = "on";
    extraArgs = ["--no-mmproj"];

    # HF_TOKEN injected at runtime from sops — never in the Nix store.
    # Guard with pathExists so the config evaluates cleanly on machines
    # that haven't staged secrets/evo-nixos.yaml yet.
    environmentFile =
      if hasSecrets
      then config.sops.templates."llama-server-env".path
      else null;
  };
}
