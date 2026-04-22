{config, lib, ...}: {
  options.pi.llamaModels = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [];
    description = ''
      Local llama-server model entries for PI's models.json and settings.json.
      Each entry must have: id, name, reasoning, input, contextWindow, maxTokens, cost.
      Set per-host to match the host's services.llama-servers configuration.
    '';
    example = lib.literalExpression ''
      [{
        id = "bartowski/Qwen_Qwen3.5-27B-GGUF";
        name = "Local Qwen 3.5 27B Dense (llama.cpp)";
        reasoning = false;
        input = ["text"];
        contextWindow = 131072;
        maxTokens = 8192;
        cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
      }]
    '';
  };

  imports = [
    ./resources.nix
  ];
}
