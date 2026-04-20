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
{pkgs, ...}: {
  services.llama-server = {
    enable = true;

    # Build llama-cpp with CUDA support for the RTX 5060 Ti (sm_120 / Blackwell)
    package = pkgs.llama-cpp.override {cudaSupport = true;};

    hfRepo = "bartowski/gemma-4-27b-it-GGUF";
    hfFile = "gemma-4-27b-it-Q4_K_M.gguf";

    # MoE model: push all layers to GPU, extra CPU threads for expert routing
    nGpuLayers = 99;
    threads = 8;

    # 32 K context — good balance of memory headroom and usability
    contextSize = 32768;

    host = "127.0.0.1";
    port = 8080;

    # Flash-attention saves VRAM during long-context inference
    extraArgs = ["--flash-attn"];
  };
}
