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
  # Personal — personal wiki (Nazar operator role)
  nazarWikiDir = "${config.home.homeDirectory}/Sync/Wiki/Personal";

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
      private = {
        cwdContains = ["/Sync/Wiki/Personal"];
        filePathContains = [
          "pages/journal"
          "pages/personal"
          "pages/areas/personal"
          "journal/daily"
          "areas/personal"
        ];
        keywords = [
          "journal entry"
          "my journal"
          "personal note"
          "health update"
          "how i feel"
          "diary"
          "private note"
        ];
      };
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
    This wiki is domain-restricted to `technical` — personal pages are never visible or writable.
  '';

  llmWikiSchema = pkgs.writeText "llm-wiki-WIKI_SCHEMA.md" ''
    # llm-wiki schema

    ## Recommendation

    Prefer **one wiki root** with:

    - domain-level metadata for `technical` vs `personal`
    - PARA-style folders for storage and browsing
    - journal notes under `pages/journal/daily/`

    This keeps search, memory digests, cross-links, and Syncthing simple.

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

    ## Journal page frontmatter

    ```yaml
    ---
    type: journal
    title: 2026-04-19 Daily Journal
    aliases: []
    tags: [journal, reflection]
    hosts: []
    domain: personal
    areas: [journal]
    status: active
    updated: 2026-04-19
    summary: One-line summary of the day
    ---
    ```

    ## Host-specific example

    ```yaml
    hosts:
      - pad-nixos
    ```

    ## Folder examples

    - `pages/resources/technical/`
    - `pages/areas/personal/`
    - `pages/projects/technical/`
    - `pages/journal/daily/`
    - `pages/technical/` and `pages/personal/` for simpler direct separation
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
    - [[areas/personal/personal-identity|Personal Identity]]
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

  llmWikiDailyJournalTemplate = pkgs.writeText "llm-wiki-daily-journal.md" ''
    ---
    type: journal
    title: {{date:YYYY-MM-DD}} Daily Journal
    aliases: []
    tags:
      - journal
      - reflection
    hosts: []
    domain: personal
    areas:
      - journal
    status: active
    updated: {{date:YYYY-MM-DD}}
    summary: Daily notes and reflection
    ---
    # {{date:YYYY-MM-DD}} Daily Journal

    ## Focus

    -

    ## Notes

    -

    ## Wins

    -

    ## Friction

    -

    ## Follow-ups

    -
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

  # ── Nazar (Personal wiki) — README ──────────────────────────────────────────
  nazarWikiReadme = pkgs.writeText "nazar-wiki-README.md" ''
    # Personal Wiki

    This wiki is shared through Syncthing at `~/Sync/Wiki/Personal`.
    Open this folder directly in Obsidian as a vault.

    This is a human + AI collaborative space. Write here directly in any markdown
    editor; Nazar (the AI operator) also captures and creates pages using wiki tools.
    It is the user/home layer — analogous to HomeManager in the NixOS/HomeManager split.

    ## Structure

    - `pages/journal/daily/` — daily journal entries
    - `pages/tasks/` — task tracking
    - `pages/areas/personal/` — personal identity and long-lived themes
    - `pages/areas/health/` — health tracking
    - `pages/projects/personal/` — personal projects
    - `pages/resources/personal/` — reference material

    ## Prompt templates

    When running `nazar`, type `/journal`, `/todo`, `/task`, `/update`, `/recap`, or `/note`.

    ## Metadata

    - use `domain: personal` for all pages here
    - use `areas: [...]` for long-lived themes
    - use `hosts: [...]` for device-specific notes

    ## Model

    Nazar uses a private, GDPR-native LLM (Cortecs) that does not train on your data.
    The technical NixPI wiki is readable for reference at `~/Sync/Wiki/NixPI/`.
    This wiki is never seen by the technical (architect) LLM.
  '';

  # ── Nazar — starter pages ────────────────────────────────────────────────────
  nazarPersonalIdentity = pkgs.writeText "nazar-personal-identity.md" ''
    ---
    type: identity
    title: Personal Identity
    aliases: []
    tags:
      - identity
      - personal
    hosts: []
    domain: personal
    areas:
      - identity
      - life-ops
    status: active
    updated: 2026-04-20
    source_ids: []
    summary: Stable personal preferences, values, and working style.
    ---
    # Personal Identity

    ## About me

    ## Values and priorities

    ## Working style

    ## Preferences

    ## Open questions

    ## Related pages

    - [[resources/personal/nazar-landscape|Nazar Landscape]]
  '';

  nazarLandscape = pkgs.writeText "nazar-landscape.md" ''
    ---
    type: concept
    title: Nazar Landscape
    aliases: []
    tags:
      - personal
      - nazar
      - operator
    hosts: []
    domain: personal
    areas:
      - life-ops
    status: active
    updated: 2026-04-20
    source_ids: []
    summary: Overview of Nazar — the personal AI operator and Personal wiki.
    ---
    # Nazar Landscape

    ## Purpose

    Nazar is the personal AI operator role — the user/home-layer equivalent of the NixPI
    architect (which handles the OS/infra layer). This mirrors the NixOS/HomeManager split:
    NixPI owns the system, Nazar owns the home.

    This wiki holds all personal knowledge: journal, tasks, notes, health, plans.
    Human-written and AI-assisted entries coexist in the same markdown files.
    Open this folder in Obsidian to contribute directly.

    ## Prompt templates

    Available via `/command` when running `nazar`:

    - `/journal` — open or continue today’s journal entry
    - `/todo` — triage and capture pending tasks
    - `/task <name>` — define and track a task
    - `/update [topic]` — write a structured update note
    - `/recap [period]` — generate a period summary from the wiki
    - `/note` — quick fleeting capture

    ## Structure

    - `pages/journal/daily/` — daily journal entries
    - `pages/tasks/` — task tracking
    - `pages/areas/personal/` — personal identity and long-lived areas
    - `pages/areas/health/` — health tracking
    - `pages/projects/personal/` — personal projects
    - `pages/resources/personal/` — reference material

    ## Access to technical knowledge

    Nazar’s private LLM can read the NixPI wiki as reference:
    use `read` or `bash` on `~/Sync/Wiki/NixPI/pages/` when technical context is needed.
    This is safe because Cortecs is GDPR-native and does not train on your data.

    ## Related pages

    - [[areas/personal/personal-identity|Personal Identity]]
  '';

  # ── Nazar — Obsidian templates ───────────────────────────────────────────────
  nazarPageTemplate = pkgs.writeText "nazar-page-template.md" ''
    ---
    type: concept
    title: New Page
    aliases: []
    tags: []
    hosts: []
    domain: personal
    areas: []
    status: draft
    updated: {{date:YYYY-MM-DD}}
    source_ids: []
    summary: One-line summary
    ---
    # New Page

    ## Notes

    ## Related pages
  '';

  # ── Nazar — prompt templates (seeded into Personal wiki .pi/prompts/) ────────
  nazarJournalPrompt = pkgs.writeText "nazar-journal-prompt.md" ''
    ---
    description: Open or continue today’s journal entry
    ---
    Open or continue my journal for today.

    1. Use wiki_ensure_page with type=journal and folder=journal/daily to get or create today’s entry.
    2. Search the Personal wiki for any unresolved follow-ups or open tasks from recent entries.
    3. Show me the current state of the page and wait for me to add notes.
  '';

  nazarTodoPrompt = pkgs.writeText "nazar-todo-prompt.md" ''
    ---
    description: Triage and capture pending tasks
    ---
    Help me triage my pending tasks.

    Search the Personal wiki for existing task pages (folder=tasks) and recent journal entries
    with unresolved follow-ups. Capture any new items I describe using wiki_ensure_page or
    wiki_capture. Group by priority and show the full picture.
  '';

  nazarTaskPrompt = pkgs.writeText "nazar-task-prompt.md" ''
    ---
    description: Define and track a specific task
    argument-hint: "<task name>"
    ---
    Create or find a task page for: $@

    Use wiki_ensure_page with type=concept, domain=personal, and folder=tasks.
    Help me define the goal clearly, break it into concrete steps, and note any blockers
    or dependencies. Update the page when done.
  '';

  nazarUpdatePrompt = pkgs.writeText "nazar-update-prompt.md" ''
    ---
    description: Write a structured update note
    argument-hint: "[topic]"
    ---
    Help me write a structured update note about: $@

    Format it as:
    - **What** — what changed or happened
    - **Why** — the reasoning or trigger
    - **Next** — what follows from this

    Capture it to the Personal wiki using wiki_capture with domain=personal when done.
  '';

  nazarRecapPrompt = pkgs.writeText "nazar-recap-prompt.md" ''
    ---
    description: Generate a period recap from the Personal wiki
    argument-hint: "[this week | this month | period]"
    ---
    Generate a recap for: $@

    Search the Personal wiki for journal entries, completed tasks, update notes, and
    captured notes from this period. Surface patterns, wins, blockers, and open threads.
    Present a clean narrative summary.
  '';

  nazarNotePrompt = pkgs.writeText "nazar-note-prompt.md" ''
    ---
    description: Quickly capture a note to the Personal wiki
    ---
    Help me capture a quick note to the Personal wiki.

    I’ll describe what I want to record. Use wiki_capture with domain=personal and
    appropriate areas and tags. Keep it brief and factual.
  '';
in {
  home.file.".config/qmd/index.yml".text = ''
    global_context: >-
      Technical and personal knowledge base. If you see a [[WikiLink]], search
      for that exact term to get more context on it.

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

      personal:
        path: ${nazarWikiDir}
        pattern: "pages/**/*.md"
        ignore:
          - "pages/sources/**"
        includeByDefault: false
        context:
          "/": "Personal wiki (Nazar operator) — journal, tasks, health, personal areas"
          "/pages/journal/daily": "Daily journal entries"
          "/pages/tasks": "Task tracking"
          "/pages/areas/health": "Health and wellness notes"
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

  home.activation.nazarWikiStarter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    nazar_root='${nazarWikiDir}'

    mkdir -p \
      "$nazar_root/pages/sources" \
      "$nazar_root/pages/journal/daily" \
      "$nazar_root/pages/tasks" \
      "$nazar_root/pages/projects/personal" \
      "$nazar_root/pages/areas/personal" \
      "$nazar_root/pages/areas/health" \
      "$nazar_root/pages/resources/personal" \
      "$nazar_root/pages/archives" \
      "$nazar_root/raw" \
      "$nazar_root/meta" \
      "$nazar_root/templates/obsidian" \
      "$nazar_root/.pi/prompts"

    [ -e "$nazar_root/README.md" ]                                      || cp ${nazarWikiReadme} "$nazar_root/README.md"
    [ -e "$nazar_root/WIKI_SCHEMA.md" ]                                  || cp ${llmWikiSchema} "$nazar_root/WIKI_SCHEMA.md"
    [ -e "$nazar_root/pages/areas/personal/personal-identity.md" ]       || cp ${nazarPersonalIdentity} "$nazar_root/pages/areas/personal/personal-identity.md"
    [ -e "$nazar_root/pages/resources/personal/nazar-landscape.md" ]     || cp ${nazarLandscape} "$nazar_root/pages/resources/personal/nazar-landscape.md"
    [ -e "$nazar_root/templates/obsidian/daily-journal.md" ]             || cp ${llmWikiDailyJournalTemplate} "$nazar_root/templates/obsidian/daily-journal.md"
    [ -e "$nazar_root/templates/obsidian/page.md" ]                      || cp ${nazarPageTemplate} "$nazar_root/templates/obsidian/page.md"
    [ -e "$nazar_root/.pi/prompts/journal.md" ]                          || cp ${nazarJournalPrompt} "$nazar_root/.pi/prompts/journal.md"
    [ -e "$nazar_root/.pi/prompts/todo.md" ]                             || cp ${nazarTodoPrompt} "$nazar_root/.pi/prompts/todo.md"
    [ -e "$nazar_root/.pi/prompts/task.md" ]                             || cp ${nazarTaskPrompt} "$nazar_root/.pi/prompts/task.md"
    [ -e "$nazar_root/.pi/prompts/update.md" ]                           || cp ${nazarUpdatePrompt} "$nazar_root/.pi/prompts/update.md"
    [ -e "$nazar_root/.pi/prompts/recap.md" ]                            || cp ${nazarRecapPrompt} "$nazar_root/.pi/prompts/recap.md"
    [ -e "$nazar_root/.pi/prompts/note.md" ]                             || cp ${nazarNotePrompt} "$nazar_root/.pi/prompts/note.md"
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
