{
  config,
  lib,
  pkgs,
  ...
}: let
  piWebAccessRoot = "${pkgs.pi-web-access}/share/pi-web-access";
  llmWikiRoot = "${pkgs.llm-wiki}/share/llm-wiki";

  # Wiki root — unified personal + technical vault, synced via Syncthing
  wikiDir = "${config.home.homeDirectory}/Workspace/Knowledge";

  # Seed directory committed to the repo — provides the canonical structure on
  # fresh devices before Syncthing has had a chance to sync.
  # Strategy: [ -e "$dest" ] || cp "$src" "$dest"
  # Syncthing wins once it syncs; the seed only fills gaps.
  wikiSeed = ./wiki-seed;

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

  # ── Local llama models — set per-host via pi.llamaModels ─────────────────
  llamaModels = config.pi.llamaModels;

  # Build enabled model IDs for PI settings.json.
  syntheticModelIds = [
    "synthetic/hf:zai-org/GLM-5.1"
    "synthetic/hf:moonshotai/Kimi-K2.5"
    "synthetic/hf:MiniMaxAI/MiniMax-M2.5"
    "synthetic/hf:Qwen/Qwen3-Coder-480B-A35B-Instruct"
  ];

  llamaModelIds = map (m: "llama/${m.id}") llamaModels;
  hasLlama = llamaModels != [];

  syntheticProvider = {
    baseUrl = "https://api.synthetic.new/openai/v1";
    apiKey = "SYNTHETIC_API_KEY";
    api = "openai-completions";
    compat = {
      supportsDeveloperRole = false;
      supportsReasoningEffort = false;
    };
    models = [
      {
        id = "hf:zai-org/GLM-5.1";
        name = "GLM 5.1 (Synthetic)";
        reasoning = true;
        input = ["text"];
        contextWindow = 196608;
        maxTokens = 65536;
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
      }
      {
        id = "hf:moonshotai/Kimi-K2.5";
        name = "Kimi K2.5 (Synthetic)";
        reasoning = true;
        input = ["text" "image"];
        contextWindow = 262144;
        maxTokens = 65536;
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
      }
      {
        id = "hf:MiniMaxAI/MiniMax-M2.5";
        name = "MiniMax M2.5 (Synthetic)";
        reasoning = true;
        input = ["text"];
        contextWindow = 196608;
        maxTokens = 65536;
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
      }
      {
        id = "hf:Qwen/Qwen3-Coder-480B-A35B-Instruct";
        name = "Qwen3 Coder 480B A35B Instruct (Synthetic)";
        reasoning = true;
        input = ["text"];
        contextWindow = 262144;
        maxTokens = 65536;
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
      }
    ];
  };

  llamaProvider = {
    baseUrl = "http://127.0.0.1:8080/v1";
    apiKey = "local";
    api = "openai-completions";
    compat = {
      supportsDeveloperRole = false;
      supportsReasoningEffort = false;
      maxTokensField = "max_tokens";
    };
    models = llamaModels;
  };

  piModelsBase = {
    providers =
      {
        synthetic = syntheticProvider;
      }
      // lib.optionalAttrs hasLlama {
        llama = llamaProvider;
      };
  };

  piModelsBaseJson = pkgs.writeText "pi-models-base.json" (builtins.toJSON piModelsBase);

  # ── PI settings.json — fully declarative ──────────────────────────────────
  piSettings = {
    lastChangelogVersion = "0.67.68";
    defaultThinkingLevel = "high";
    hideThinkingBlock = true;
    defaultProvider = "synthetic";
    defaultModel = "hf:zai-org/GLM-5.1";
    enabledModels = syntheticModelIds ++ llamaModelIds;
    mcpServers = {
      qmd = {
        command = "qmd";
        args = ["mcp"];
      };
    };
  };

  piSettingsJson = pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings);
in {
  # ── qmd — local retrieval layer ───────────────────────────────────────────
  home.file.".config/qmd/index.yml".text = ''
    global_context: >-
      Unified personal + technical knowledge base using an object model.
      Notes have stable ids, object_type, and typed relation fields.
      Folders express role: planner, projects, areas, resources, sources, journal.
      domain: technical or personal separates scope. summary field is the
      first routing hint. schema_version: 1, validation_level tracks maturity.

    collections:
      wiki:
        path: ${wikiDir}
        pattern: "pages/**/*.md"
        context:
          "/": "Unified wiki — personal and technical knowledge in one object graph"
          "/pages/home": "Dashboards and navigation entry points"
          "/pages/planner": "Operational layer: tasks, calendar, reminders, reviews"
          "/pages/planner/tasks": "Actionable tasks with status, priority, due dates"
          "/pages/planner/calendar": "Scheduled events and meetings"
          "/pages/planner/reminders": "Time-based prompts and follow-ups"
          "/pages/planner/reviews": "Weekly, monthly, and periodic review notes"
          "/pages/projects": "Finite outcome projects, one folder per project"
          "/pages/areas": "Long-lived responsibilities and life/system domains"
          "/pages/resources": "Reference knowledge: people, technical, concepts"
          "/pages/resources/people": "Person objects — relationship context and open loops"
          "/pages/resources/technical": "Technical entities: hosts, services, tools"
          "/pages/resources/knowledge": "Evergreen concepts and knowledge notes"
          "/pages/sources": "Captured research, imported evidence, source summaries"
          "/pages/journal": "Time-based logs and reflections"
          "/pages/journal/daily": "Daily notes"
          "/pages/journal/weekly": "Weekly reflections"
          "/pages/journal/monthly": "Monthly summaries"
  '';

  # ── PI config stubs ───────────────────────────────────────────────────────
  home.file.".pi/agent/prompts/.keep".text = "";
  home.file.".pi/agent/prompts/wiki.md".source = ./prompts/wiki.md;
  home.file.".pi/agent/skills/.keep".text = "";
  home.file.".pi/agent/themes/.keep".text = "";
  home.file.".pi/agent/agents/.keep".text = "";

  # ── PI extensions ─────────────────────────────────────────────────────────
  home.file.".pi/agent/extensions/zz-synthetic-search".source = ./extensions/zz-synthetic-search;
  home.file.".pi/agent/extensions/llm-wiki".source = llmWikiRoot;
  home.file.".pi/agent/extensions/persona".source = ./extensions/persona;
  home.file.".pi/agent/extensions/os".source = ./extensions/os;
  home.file.".pi/agent/extensions/nixpi".source = ./extensions/nixpi;
  home.file.".pi/agent/extensions/subagent".source = ./extensions/subagent;
  home.file.".pi/agent/extensions/sudo-auth" = {
    source = ./extensions/sudo-auth;
    force = true;
  };

  # ── PI skills ─────────────────────────────────────────────────────────────
  home.file.".pi/agent/skills/librarian/SKILL.md".source = "${piWebAccessRoot}/skills/librarian/SKILL.md";
  home.file.".pi/agent/skills/wiki/SKILL.md".source = ./skills/wiki/SKILL.md;
  home.file.".pi/agent/skills/wiki-migration/SKILL.md".source = ./skills/wiki-migration/SKILL.md;
  home.file.".pi/agent/skills/wiki-migration/scripts/scan.sh".source = ./skills/wiki-migration/scripts/scan.sh;
  home.file.".pi/agent/skills/wiki-migration/scripts/batch-list.sh".source = ./skills/wiki-migration/scripts/batch-list.sh;
  home.file.".pi/agent/skills/os-operations/SKILL.md".source = ./skills/os-operations/SKILL.md;
  home.file.".pi/agent/skills/self-evolution/SKILL.md".source = ./skills/self-evolution/SKILL.md;
  home.file.".pi/agent/skills/provisioning/SKILL.md".source = ./skills/provisioning/SKILL.md;
  home.file.".pi/agent/skills/first-boot/SKILL.md".source = ./skills/first-boot/SKILL.md;

  # ── PI subagents ──────────────────────────────────────────────────────────
  home.file.".pi/agent/agents/scout.md".source = ./agents/scout.md;
  home.file.".pi/agent/agents/planner.md".source = ./agents/planner.md;
  home.file.".pi/agent/agents/worker.md".source = ./agents/worker.md;
  home.file.".pi/agent/agents/reviewer.md".source = ./agents/reviewer.md;

  # ── Session variables ─────────────────────────────────────────────────────
  home.sessionVariables.PI_LLM_WIKI_DIR = wikiDir;
  home.sessionVariables.PI_LLM_WIKI_ALLOWED_DOMAINS = "technical,personal";

  # ── Synthetic API key from local secret file ────────────────────────────
  # Set a placeholder so the session-var file is generated; activation
  # overwrites it with the real key from ~/.config/nixos-secrets/.
  home.sessionVariables.SYNTHETIC_API_KEY = "PLACEHOLDER_SYNTHETIC_KEY";
  home.activation.syntheticApiKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
    keyFile="$HOME/.config/nixos-secrets/synthetic-api-key"
    if [ -f "$keyFile" ]; then
      key=$(cat "$keyFile" | tr -d '[:space:]')
      envd="$HOME/.config/environment.d/10-home-manager.conf"
      if [ -f "$envd" ]; then
        ${pkgs.gnused}/bin/sed -i \
          "s|SYNTHETIC_API_KEY=.*|SYNTHETIC_API_KEY=$key|" "$envd"
      fi
    fi
  '';

  # ── Activation: PI web-search config (once) ───────────────────────────────
  home.activation.piWebAccessStarter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config_path="$HOME/.pi/web-search.json"
    if [ ! -e "$config_path" ]; then
      mkdir -p "$HOME/.pi"
      printf '%s\n' '${starterConfig}' > "$config_path"
    fi
  '';

  # ── Activation: PI settings — fully declarative ───────────────────────────
  #
  # settings.json is now regenerated from Nix config on every activation.
  # This ensures enabledModels, defaultModel, and mcpServers stay in sync
  # with the NixOS configuration.  User-only prefs (e.g. keybindings, UI
  # state) are preserved by merging the declarative fields into the
  # existing file rather than overwriting it entirely.
  home.activation.piSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    settings_path="$HOME/.pi/agent/settings.json"
    mkdir -p "$(dirname "$settings_path")"

    if [ ! -e "$settings_path" ]; then
      # Fresh install — write the full declarative settings
      cp ${piSettingsJson} "$settings_path"
      chmod 0600 "$settings_path"
    else
      # Existing settings — merge declarative fields, preserving user prefs
      # like keybindings, hideThinkingBlock, etc.
      ${pkgs.jq}/bin/jq -n \
        --slurpfile decl ${piSettingsJson} \
        --slurpfile cur "$settings_path" \
        '$decl[0] as $d | $cur[0] as $c |
         $c * {
           enabledModels: $d.enabledModels,
           defaultProvider: $d.defaultProvider,
           defaultModel: $d.defaultModel,
           mcpServers: ($c.mcpServers // {} | . + $d.mcpServers)
         }' \
        > "$settings_path.tmp" && mv "$settings_path.tmp" "$settings_path"
    fi
  '';

  # ── Activation: Pi custom providers/models (declarative) ─────────────────
  home.activation.piModels = lib.hm.dag.entryAfter ["writeBoundary"] ''
    models_path="$HOME/.pi/agent/models.json"
    mkdir -p "$(dirname "$models_path")"
    cp ${piModelsBaseJson} "$models_path.tmp"
    chmod 0600 "$models_path.tmp"
    mv "$models_path.tmp" "$models_path"
  '';

  # ── Activation: guardrails seed (idempotent) ──────────────────────────────
  home.activation.piGuardrails = lib.hm.dag.entryAfter ["writeBoundary"] ''
    guardrails_path="$HOME/.pi/agent/guardrails.yaml"
    mkdir -p "$(dirname "$guardrails_path")"
    if [ ! -e "$guardrails_path" ]; then
      cp ${./extensions/persona/guardrails.yaml} "$guardrails_path"
    fi
  '';

  # Remove the older privilege extensions replaced by sudo-auth.
  home.activation.piSudoCleanup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    rm -rf "$HOME/.pi/agent/extensions/sudo-prompt"
    rm -rf "$HOME/.pi/agent/extensions/sudo-handoff"
    rm -rf "$HOME/.pi/agent/extensions/tmux-manager"
  '';

  # ── Activation: wiki seed (idempotent — never overwrites existing files) ──
  #
  # On a fresh device: seeds the full canonical wiki structure from wiki-seed/.
  # Once Syncthing syncs personal content: Syncthing wins for all files.
  # The [ -e "$dest" ] || cp guard ensures no file is ever overwritten.
  #
  home.activation.wikiStarter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    wiki_root='${wikiDir}'
    seed='${wikiSeed}'

    # Create directory skeleton (safe to run repeatedly)
    mkdir -p \
      "$wiki_root/.stfolder" \
      "$wiki_root/raw" \
      "$wiki_root/meta" \
      "$wiki_root/schemas" \
      "$wiki_root/templates/markdown" \
      "$wiki_root/pages/home" \
      "$wiki_root/pages/planner/tasks" \
      "$wiki_root/pages/planner/calendar" \
      "$wiki_root/pages/planner/reminders" \
      "$wiki_root/pages/planner/reviews" \
      "$wiki_root/pages/projects" \
      "$wiki_root/pages/projects/nixpi/persona" \
      "$wiki_root/pages/projects/nixpi/evolution" \
      "$wiki_root/pages/areas" \
      "$wiki_root/pages/resources/knowledge" \
      "$wiki_root/pages/resources/people" \
      "$wiki_root/pages/resources/technical" \
      "$wiki_root/pages/resources/personal" \
      "$wiki_root/pages/sources" \
      "$wiki_root/pages/journal/daily" \
      "$wiki_root/pages/journal/weekly" \
      "$wiki_root/pages/journal/monthly" \
      "$wiki_root/pages/archives/planner" \
      "$wiki_root/pages/archives/projects" \
      "$wiki_root/pages/archives/areas" \
      "$wiki_root/pages/archives/resources" \
      "$wiki_root/pages/archives/journal"

    # Seed files — only if the destination does not already exist
    while IFS= read -r src; do
      rel="''${src#$seed/}"
      dest="$wiki_root/$rel"
      if [ ! -e "$dest" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
      fi
    done < <(find "$seed" -type f)

    # Seed an empty registry if none exists yet
    if [ ! -e "$wiki_root/meta/registry.json" ]; then
      printf '[]\n' > "$wiki_root/meta/registry.json"
    fi
  '';

  # ── Update status timer — checks if NixPI repo is behind origin ────────
  systemd.user.services.nixpi-update-check = {
    Unit.Description = "NixPI repo update check";
    Service = {
      Type = "oneshot";
      ExecStart = let
        script = pkgs.writeShellScript "nixpi-update-check" ''
          set -euo pipefail
          repo="${config.home.homeDirectory}/Workspace/NixPI"
          status_file="${config.home.homeDirectory}/.pi/agent/update-status.json"
          mkdir -p "$(dirname "$status_file")"

          branch=$(git -C "$repo" branch --show-current 2>/dev/null || echo "main")
          git -C "$repo" fetch --quiet origin 2>/dev/null || true

          behind=$(git -C "$repo" rev-list "HEAD..origin/$branch" --count 2>/dev/null || echo "0")
          available="false"
          [ "$behind" -gt 0 ] && available="true"

          printf '{"available":%s,"behindBy":%s,"checked":"%s","branch":"%s","notified":false}\n' \
            "$available" "$behind" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$branch" \
            > "$status_file"
        '';
      in "${script}";
    };
  };

  systemd.user.timers.nixpi-update-check = {
    Unit.Description = "NixPI repo update check timer";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "12h";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
