{config, ...}: {
  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      ls = "eza";
      ll = "eza -lah";
      la = "eza -a";
    };

    historySize = 10000;
    historyFileSize = 10000;
    historyFile = "${config.home.homeDirectory}/.bash_history";
    historyControl = [
      "erasedups"
      "ignoredups"
    ];

    initExtra = ''
      if [ -r /run/secrets/github-token ]; then
        export GITHUB_TOKEN="$(< /run/secrets/github-token)"
        export GH_TOKEN="$GITHUB_TOKEN"
      fi

      # Knowledge wiki shortcut
      obsidian-wiki() {
        nohup obsidian "$HOME/Workspace/Knowledge" >/dev/null 2>&1 &
      }

      # Wiki shortcut for the AI assistant context
      wiki-technical() {
        export PI_LLM_WIKI_DIR="$HOME/Workspace/Knowledge"
        echo "Wiki context: Knowledge ($PI_LLM_WIKI_DIR)"
      }
    '';
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # vivid: generates LS_COLORS from a named theme — gives eza/ls coloured output
  # without hardcoding ANSI escape strings.
  programs.vivid = {
    enable = true;
    enableBashIntegration = true;
    activeTheme = "molokai";
  };
}
