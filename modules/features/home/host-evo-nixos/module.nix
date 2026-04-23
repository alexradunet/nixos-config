{config, ...}: {
  # In-house extensions are now bundled as home.file declarations.
  # Use pi.nixpiExtensions for in-house packages that need runtime install.
  # Use pi.publicExtensions for third-party packages.
  pi.nixpiExtensions = [];
  pi.publicExtensions = [];


  # ── Local llama models available on this host ────────────────────────────
  pi.llamaModels = [
    {
      id = "bartowski/Qwen_Qwen3.5-27B-GGUF";
      name = "Local Qwen 3.5 27B Dense (llama.cpp)";
      reasoning = false;
      input = ["text"];
      contextWindow = 131072;
      maxTokens = 8192;
      cost = {
        input = 0;
        output = 0;
        cacheRead = 0;
        cacheWrite = 0;
      };
    }
  ];
}
