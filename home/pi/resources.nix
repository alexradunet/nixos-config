{ lib, pkgs, ... }:

let
  piWebAccess = pkgs.callPackage ../../pkgs/pi-web-access { };
  piWebAccessRoot = "${piWebAccess}/share/pi-web-access";
in
{
  # Create the standard Pi global resource directories.
  # The directories stay writable for Pi and manual experimentation; only the
  # placeholder files are managed declaratively.
  home.file.".pi/agent/extensions/.keep".text = "";
  home.file.".pi/agent/prompts/.keep".text = "";
  home.file.".pi/agent/skills/.keep".text = "";
  home.file.".pi/agent/themes/.keep".text = "";

  # Bundle pi-web-access as a globally available Pi extension.
  home.file.".pi/agent/extensions/pi-web-access".source = piWebAccessRoot;
  home.file.".pi/agent/skills/librarian/SKILL.md".source =
    "${piWebAccessRoot}/skills/librarian/SKILL.md";

  # Seed pi-web-access config once, then leave it mutable for Pi commands.
  home.activation.piWebAccessStarter = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_path="$HOME/.pi/web-search.json"
    if [ ! -e "$config_path" ]; then
      mkdir -p "$HOME/.pi"
      cat > "$config_path" <<'EOF'
{
  "provider": "exa",
  "workflow": "summary-review",
  "curatorTimeoutSeconds": 20,
  "githubClone": {
    "enabled": true,
    "maxRepoSizeMB": 350,
    "cloneTimeoutSeconds": 30,
    "clonePath": "/tmp/pi-github-repos"
  },
  "youtube": {
    "enabled": true,
    "preferredModel": "gemini-3-flash-preview"
  },
  "video": {
    "enabled": true,
    "preferredModel": "gemini-3-flash-preview",
    "maxSizeMB": 50
  },
  "shortcuts": {
    "curate": "ctrl+shift+s",
    "activity": "ctrl+shift+w"
  }
}
EOF
    fi
  '';
}
