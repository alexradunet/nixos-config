{config, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ls = "eza";
      ll = "eza -lah";
      la = "eza -a";
    };

    history = {
      size = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreAllDups = true;
    };

    initContent = ''
      if [ -r /run/secrets/github-token ]; then
        export GITHUB_TOKEN="$(< /run/secrets/github-token)"
        export GH_TOKEN="$GITHUB_TOKEN"
      fi

      # Obsidian vault shortcuts
      obsidian-nixpi() { obsidian "$HOME/Sync/Wiki/NixPI" &! }

      # Wiki shortcuts for the AI assistant context
      wiki-technical() {
        export PI_LLM_WIKI_DIR="$HOME/Sync/Wiki/NixPI"
        echo "Wiki context: Technical (NixPI)"
      }
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # vivid: generates LS_COLORS from a named theme — gives eza/ls coloured output
  # without hardcoding ANSI escape strings.
  programs.vivid = {
    enable = true;
    activeTheme = "molokai";
  };
}
