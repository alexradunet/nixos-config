{
  config,
  lib,
  pkgs,
  ...
}: let
  piWebAccessRoot = "${pkgs.pi-web-access}/share/pi-web-access";
  llmWikiRoot = "${pkgs.llm-wiki}/share/llm-wiki";
  # NixPI — technical wiki (architect / developer / maintainer role)
  nixpiWikiDir = "${config.home.homeDirectory}/Sync/Wiki/NixPI";

  llmRouterBase = {
    _comment = "LLM Router config — managed by NixOS (modules/features/home/pi/resources.nix). Manual edits are overwritten on rebuild.";
    private = {
      provider = "cortecs";
      model = "minimax-m2.7";
      label = "Private";
    };
    technical = {
      provider = "github-copilot";
      model = "claude-sonnet-4.6";
      label = "Technical";
    };
    providers = {
      cortecs = {
        baseUrl = "https://api.cortecs.ai/v1";
        # apiKey is injected at activation time from /run/secrets/cortecs-api-key
        apiKey = "SOPS_PLACEHOLDER";
        api = "openai-completions";
        models = [
          {
            # eu_native: true is injected per-request via the before_provider_request extension hook
            id = "minimax-m2.7";
            name = "MiniMax M2.7 (via Cortecs)";
            reasoning = false;
            input = ["text"];
            cost = {
              input = 0.3;
              output = 1.2;
              cacheRead = 0;
              cacheWrite = 0;
            };
            contextWindow = 204800;
            maxTokens = 131072;
          }
        ];
      };
    };
    rules = {
      technical = {
        cwdContains = ["/Repos" "/nixos-config" "/code" "/src" "/projects" "/Sync/Wiki/NixPI"];
        filePathContains = [
          "pages/technical"
          "pages/resources/technical"
          "pages/areas/infrastructure"
          "areas/infrastructure"
        ];
        keywords = [];
      };
    };
    defaultMode = "technical";
    autoSwitch = true;
    showNotifications = true;
  };

  llmRouterBaseJson = pkgs.writeText "llm-router-base.json" (builtins.toJSON llmRouterBase);

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

  nixpiWikiReadme = pkgs.writeText "nixpi-wiki-README.md" ''
    # NixPI Wiki

    This wiki is shared through Syncthing at `~/Sync/Wiki/NixPI`.
    Open this folder directly in Obsidian as a vault.

    This wiki covers all technical knowledge: NixOS configuration, PI agent,
    infrastructure, architecture, and domain-specific technical knowledge.
    It is the OS/system layer — analogous to NixOS in the NixOS/HomeManager split.

    ## Structure

    PARA folders:

    - `pages/projects/technical/`
    - `pages/areas/technical/`
    - `pages/resources/technical/`
    - `pages/archives/`
    - `pages/technical/` for direct technical notes

    ## Metadata conventions

    - use `domain: technical` for all pages here
    - use `areas: [nixos, pi, infrastructure, ai, ...]` for long-lived themes
    - use `hosts: [...]` for host-specific knowledge

    ## Model

    The architect LLM (smart, public) operates here.
    This wiki is domain-restricted to `technical`.
  '';

  llmWikiSchema = pkgs.writeText "llm-wiki-WIKI_SCHEMA.md" ''
    # llm-wiki schema

    ## Recommendation

    Prefer a technical-first wiki layout with PARA-style folders for storage and browsing.

    ## Canonical page frontmatter

    ```yaml
    ---
    type: concept | entity | synthesis | analysis | evolution | procedure | decision | identity
    title: Example Title
    aliases: []
    tags: [nixos, pi]
    hosts: []
    domain: technical
    areas: [infrastructure, ai]
    status: active
    updated: 2026-04-19
    source_ids: []
    summary: One-line summary
    ---
    ```

    ## Host-specific example

    ```yaml
    hosts:
      - pad-nixos
    ```

    ## Folder examples

    - `pages/resources/technical/`
    - `pages/areas/technical/`
    - `pages/projects/technical/`
    - `pages/technical/`
  '';

  llmWikiTechnicalStarter = pkgs.writeText "llm-wiki-system-landscape.md" ''
    ---
    type: concept
    title: System Landscape
    aliases: []
    tags:
      - nixos
      - pi
      - para
    hosts: []
    domain: technical
    areas:
      - infrastructure
      - ai
    status: active
    updated: 2026-04-19
    source_ids: []
    summary: High-level overview of the shared technical environment.
    ---
    # System Landscape

    ## Current understanding

    - This wiki root is shared across devices through Syncthing.
    - The vault can be edited directly from Obsidian.
    - Technical knowledge should usually use `domain: technical`.
    - PARA folders help separate projects, areas, resources, and archives.
    - Host-specific notes should use the `hosts:` field.

    ## Evidence

    - The repository exports `PI_LLM_WIKI_DIR=~/Sync/Wiki/NixPI`.
    - The llm-wiki extension filters host-specific pages by the current hostname.

    ## Tensions / caveats

    - Some technical preferences are global, while others are host-specific.
    - Folder structure and frontmatter should reinforce each other.

    ## Open questions

    - Which technical notes belong in projects vs areas vs resources?
    - Which topics deserve dedicated area pages?

    ## Related pages

    - [[resources/technical/pad-nixos|pad-nixos]]
  '';

  llmWikiPadStarter = pkgs.writeText "llm-wiki-pad-nixos.md" ''
    ---
    type: entity
    title: pad-nixos
    aliases: []
    tags:
      - host
      - laptop
    hosts:
      - pad-nixos
    domain: technical
    areas:
      - infrastructure
      - laptop
    status: active
    updated: 2026-04-19
    source_ids: []
    summary: Laptop-specific notes and constraints.
    ---
    # pad-nixos

    ## Current understanding

    - This page is visible primarily when the current host is `pad-nixos`.
    - Use this pattern for device-specific hardware, workflows, and quirks.

    ## Evidence

    - The page frontmatter sets `hosts: [pad-nixos]`.

    ## Tensions / caveats

    - Avoid putting globally relevant knowledge here.

    ## Open questions

    - Which laptop-only workflows should live here versus in global technical pages?

    ## Related pages

    - [[resources/technical/system-landscape|System Landscape]]
  '';

  llmWikiPageTemplate = pkgs.writeText "llm-wiki-page-template.md" ''
    ---
    type: concept
    title: New Page
    aliases: []
    tags: []
    hosts: []
    domain: technical
    areas: []
    status: draft
    updated: {{date:YYYY-MM-DD}}
    source_ids: []
    summary: One-line summary
    ---
    # New Page

    <!-- Rename the title and move the note into the right PARA/domain folder after inserting this template. -->

    ## Current understanding

    ## Evidence

    ## Tensions / caveats

    ## Open questions

    ## Related pages
  '';
in {
  home.file.".config/qmd/index.yml".text = ''
    global_context: >-
      Technical knowledge base. If you see a [[WikiLink]], search for that exact
      term to get more context on it.

    collections:
      nixpi:
        path: ${nixpiWikiDir}
        pattern: "pages/**/*.md"
        ignore:
          - "pages/sources/**"
        context:
          "/": "NixPI technical wiki — NixOS config, Pi agent, infrastructure, AI, and architecture"
          "/pages/journal": "Technical journal entries"
          "/pages/technical": "Direct technical notes"
          "/pages/resources/technical": "Technical reference pages"
          "/pages/areas/technical": "Long-lived technical areas"
  '';

  home.file.".pi/agent/prompts/.keep".text = "";
  home.file.".pi/agent/skills/.keep".text = "";
  home.file.".pi/agent/themes/.keep".text = "";

  home.file.".pi/agent/extensions/pi-web-access".source = piWebAccessRoot;
  home.file.".pi/agent/extensions/llm-wiki".source = llmWikiRoot;
  home.file.".pi/agent/extensions/wg-admin".source = ./extensions/wg-admin;
  home.file.".pi/agent/skills/librarian/SKILL.md".source = "${piWebAccessRoot}/skills/librarian/SKILL.md";
  home.file.".pi/agent/skills/wg-admin/SKILL.md".source = ./skills/wg-admin/SKILL.md;

  home.sessionVariables.PI_LLM_WIKI_DIR = nixpiWikiDir;
  home.sessionVariables.PI_LLM_WIKI_ALLOWED_DOMAINS = "technical";

  home.activation.piWebAccessStarter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config_path="$HOME/.pi/web-search.json"
    if [ ! -e "$config_path" ]; then
      mkdir -p "$HOME/.pi"
      printf '%s\n' '${starterConfig}' > "$config_path"
    fi
  '';

  home.activation.nixpiWikiStarter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    nixpi_root='${nixpiWikiDir}'

    # Migrate from the old single-wiki path if it still exists
    old_root="$HOME/Sync/llm-wiki"
    if [ -d "$old_root" ] && [ ! -d "$nixpi_root" ]; then
      mkdir -p "$HOME/Sync/Wiki"
      mv "$old_root" "$nixpi_root"
    fi

    mkdir -p \
      "$nixpi_root/pages/sources" \
      "$nixpi_root/pages/projects/technical" \
      "$nixpi_root/pages/areas/technical" \
      "$nixpi_root/pages/resources/technical" \
      "$nixpi_root/pages/archives" \
      "$nixpi_root/pages/technical" \
      "$nixpi_root/raw" \
      "$nixpi_root/meta" \
      "$nixpi_root/templates/obsidian"

    [ -e "$nixpi_root/README.md" ]                                          || cp ${nixpiWikiReadme} "$nixpi_root/README.md"
    [ -e "$nixpi_root/WIKI_SCHEMA.md" ]                                     || cp ${llmWikiSchema} "$nixpi_root/WIKI_SCHEMA.md"
    [ -e "$nixpi_root/pages/resources/technical/system-landscape.md" ]      || cp ${llmWikiTechnicalStarter} "$nixpi_root/pages/resources/technical/system-landscape.md"
    [ -e "$nixpi_root/pages/resources/technical/pad-nixos.md" ]             || cp ${llmWikiPadStarter} "$nixpi_root/pages/resources/technical/pad-nixos.md"
    [ -e "$nixpi_root/templates/obsidian/page.md" ]                         || cp ${llmWikiPageTemplate} "$nixpi_root/templates/obsidian/page.md"
  '';

  # Write llm-router.json and inject cortecs API key from sops secret
  home.activation.llmRouter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    llm_router_path="$HOME/.pi/agent/llm-router.json"
    secret_path="/run/secrets/cortecs-api-key"
    mkdir -p "$(dirname "$llm_router_path")"
    if [ -r "$secret_path" ]; then
      api_key=$(cat "$secret_path")
      ${pkgs.jq}/bin/jq --arg key "$api_key" \
        '.providers.cortecs.apiKey = $key' \
        ${llmRouterBaseJson} > "$llm_router_path"
    else
      cp ${llmRouterBaseJson} "$llm_router_path"
    fi
  '';
}
