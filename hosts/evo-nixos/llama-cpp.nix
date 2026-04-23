# llama-server configuration for evo-nixos
#
# Primary local model endpoint:
# - llama-server-vulkan on 127.0.0.1:8080
# - model: bartowski/Qwen_Qwen3.5-27B-GGUF (dense 27B)
# - OpenAI-compatible API bound to localhost only
{pkgs, ...}: let
  vulkanPkg = pkgs.llama-cpp.override {vulkanSupport = true;};
in {
  boot.kernelParams = [
    "ttm.pages_limit=14155776"
    "ttm.page_pool_size=14155776"
  ];

  boot.initrd.kernelModules = ["amdgpu"];

  services.llama-servers.vulkan = {
    enable = true;
    package = vulkanPkg;
    port = 8080;
    hfRepo = "bartowski/Qwen_Qwen3.5-27B-GGUF";
    hfFile = "Qwen_Qwen3.5-27B-Q4_K_M.gguf";
    modelId = "bartowski/Qwen_Qwen3.5-27B-GGUF";
    modelName = "Local Qwen 3.5 27B Dense (llama.cpp)";
    nGpuLayers = 99;
    threads = 12;
    contextSize = 131072;
    environmentVariables = {
      CUDA_VISIBLE_DEVICES = "-1";
      GGML_VK_VISIBLE_DEVICES = "0";
      LLAMA_ARG_FLASH_ATTN = "on";
    };
    extraArgs = [
      "--no-mmproj"
      "--reasoning-budget"
      "0"
      "--metrics"
      "--slots"
    ];
  };
}
