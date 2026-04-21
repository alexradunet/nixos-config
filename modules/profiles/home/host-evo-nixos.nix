{config, ...}: {
  flake.homeModules.profile-host-evo-nixos = {
    imports = [
      config.flake.homeModules.profile-base
      config.flake.homeModules.llm-agents
      config.flake.homeModules.ghostty
      config.flake.homeModules.tmux
      config.flake.homeModules.host-evo-nixos
    ];
  };
}
