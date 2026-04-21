# llama-server configuration for evo-nixos
#
# Two independent inference instances, each pinned to its own GPU:
#
#   cuda   → NVIDIA RTX 5060 Ti (16 GB VRAM, CUDA)   port 8080
#            Model: Gemma 4 27B-IT (MoE, ~4B active, Q4_K_M ~12.4 GB)
#            Fast dense inference, 128K context, flash-attn
#
#   vulkan → AMD Radeon 890M iGPU (64 GB unified RAM, Vulkan) port 8081
#            Model: Qwen3-30B-A3B (MoE, ~3B active, Q4_K_M ~17 GB)
#            Huge context / long-document work, flash-attn
#
# Vulkan device mapping (confirmed via vulkaninfo --summary):
#   GPU0 = AMD Radeon 890M  (RADV)   ← GGML_VK_VISIBLE_DEVICES=0
#   GPU1 = NVIDIA RTX 5060 Ti        ← hidden from vulkan instance via CUDA_VISIBLE_DEVICES=-1
#
# First-start model downloads (~12 GB CUDA, ~17 GB Vulkan) land in each
# instance's own HF cache:
#   /var/lib/llama-server-cuda/hf-cache
#   /var/lib/llama-server-vulkan/hf-cache
#
# Migration note — if upgrading from the old singleton llama-server:
#   sudo systemctl stop llama-server
#   sudo mv /var/lib/llama-server /var/lib/llama-server-cuda
#   sudo chown -R llama-server-cuda:llama-server-cuda /var/lib/llama-server-cuda
#
# Monitor:
#   journalctl -u llama-server-cuda   -f
#   journalctl -u llama-server-vulkan -f
#   curl http://127.0.0.1:8080/health
#   curl http://127.0.0.1:8081/health
{
  config,
  lib,
  pkgs,
  ...
}: let
  secretFile = ../../secrets/evo-nixos.yaml;
  hasSecrets = builtins.pathExists secretFile;

  cudaPkg   = pkgs.llama-cpp.override {cudaSupport = true;};
  vulkanPkg = pkgs.llama-cpp.override {vulkanSupport = true;};
in {
  # Expose llama-* CLI tools for both backends in PATH
  environment.systemPackages = [cudaPkg vulkanPkg];

  # Give the AMD iGPU access to a large slice of the 64 GB unified RAM pool.
  # ttm.pages_limit is in 4K pages; 14155776 pages = ~54 GB.
  # The remaining ~10 GB stays available for the OS and CPU workloads.
  boot.kernelParams = [
    "ttm.pages_limit=14155776"
    "ttm.page_pool_size=14155776"
  ];

  # Ensure amdgpu is loaded early so the iGPU is ready before the service starts
  boot.initrd.kernelModules = ["amdgpu"];

  # Sops environment files — one per instance, each owned by its service user
  sops.templates."llama-server-cuda-env" = lib.mkIf hasSecrets {
    content = ''HF_TOKEN=${config.sops.placeholder."hf-token"}'';
    owner = "llama-server-cuda";
    group = "llama-server-cuda";
    mode = "0400";
  };

  sops.templates."llama-server-vulkan-env" = lib.mkIf hasSecrets {
    content = ''HF_TOKEN=${config.sops.placeholder."hf-token"}'';
    owner = "llama-server-vulkan";
    group = "llama-server-vulkan";
    mode = "0400";
  };

  services.llama-servers = {
    # ── NVIDIA RTX 5060 Ti — CUDA ─────────────────────────────────────────
    cuda = {
      enable  = true;
      package = cudaPkg;
      port    = 8080;

      hfRepo = "bartowski/google_gemma-4-26B-A4B-it-GGUF";
      hfFile = "google_gemma-4-26B-A4B-it-IQ3_XS.gguf";

      nGpuLayers  = 99;
      threads     = 8;
      contextSize = 131072; # 128K — within Gemma 4's 256K window

      environmentVariables = {
        # Pin this instance to the NVIDIA card only
        CUDA_VISIBLE_DEVICES       = "0";
        LLAMA_ARG_FLASH_ATTN       = "on";
      };

      extraArgs = [
        "--no-mmproj"        # skip vision encoder (~1.1 GB saved)
        "--cache-type-k" "q8_0"
        "--cache-type-v" "q8_0"
      ];

      environmentFile =
        if hasSecrets
        then config.sops.templates."llama-server-cuda-env".path
        else null;
    };

    # ── AMD Radeon 890M — Vulkan ───────────────────────────────────────────
    vulkan = {
      enable  = true;
      package = vulkanPkg;
      port    = 8081;

      # Qwen3-30B-A3B: 30B total / 3B active MoE — ideal for unified RAM
      # ~17 GB at Q4_K_M, leaving ~47 GB for KV cache and OS
      hfRepo = "bartowski/Qwen3-30B-A3B-Instruct-GGUF";
      hfFile = "Qwen3-30B-A3B-Instruct-Q4_K_M.gguf";

      nGpuLayers  = 99;
      threads     = 12; # more CPU threads — expert routing on MoE
      contextSize = 65536; # 64K — comfortable within unified RAM budget

      environmentVariables = {
        # Hide NVIDIA from CUDA detection so it doesn't interfere
        CUDA_VISIBLE_DEVICES    = "-1";
        # AMD 890M is Vulkan device 0 (confirmed via vulkaninfo --summary)
        GGML_VK_VISIBLE_DEVICES = "0";
        LLAMA_ARG_FLASH_ATTN    = "on";
      };

      extraArgs = [
        "--cache-type-k" "q8_0"
        "--cache-type-v" "q8_0"
      ];

      environmentFile =
        if hasSecrets
        then config.sops.templates."llama-server-vulkan-env".path
        else null;
    };
  };
}
