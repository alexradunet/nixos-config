{
  config,
  lib,
  pkgs,
  ...
}: let
  piWebAccessRoot = "${pkgs.pi-web-access}/share/pi-web-access";
  piLlmWikiRoot = "${pkgs.pi-llm-wiki}/share/pi-llm-wiki";
  starterConfig = builtins.toJSON {
    provider = "exa";
    workflow = "summary-review";
    curatorTimeoutSeconds = 20;
    githubClone = {
      enabled = true;
      maxRepoSizeMB = 350;
      cloneTimeoutSeconds = 30;
      clonePath = "/tmp/pi-github-repos";
    };
    youtube = {
      enabled = true;
      preferredModel = "gemini-3-flash-preview";
    };
    video = {
      enabled = true;
      preferredModel = "gemini-3-flash-preview";
      maxSizeMB = 50;
    };
    shortcuts = {
      curate = "ctrl+shift+s";
      activity = "ctrl+shift+w";
    };
  };
in {
  # Create the standard Pi global resource directories.
  # The directories stay writable for Pi and manual experimentation; only the
  # placeholder files are managed declaratively.
  home.file.".pi/agent/extensions/.keep".text = "";
  home.file.".pi/agent/prompts/.keep".text = "";
  home.file.".pi/agent/skills/.keep".text = "";
  home.file.".pi/agent/themes/.keep".text = "";

  # Bundle global Pi extensions and skills.
  home.file.".pi/agent/extensions/pi-web-access".source = piWebAccessRoot;
  home.file.".pi/agent/extensions/pi-llm-wiki".source = piLlmWikiRoot;
  home.file.".pi/agent/skills/librarian/SKILL.md".source = "${piWebAccessRoot}/skills/librarian/SKILL.md";

  # Put the shared llm-wiki in Sync so Syncthing keeps it aligned across hosts.
  home.sessionVariables.PI_LLM_WIKI_DIR = "${config.home.homeDirectory}/Sync/llm-wiki";

  # Seed pi-web-access config once, then leave it mutable for Pi commands.
  home.activation.piWebAccessStarter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config_path="$HOME/.pi/web-search.json"
    if [ ! -e "$config_path" ]; then
      mkdir -p "$HOME/.pi"
      printf '%s\n' '${starterConfig}' > "$config_path"
    fi
  '';
}
