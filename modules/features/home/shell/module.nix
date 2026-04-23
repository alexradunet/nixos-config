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

    # wiki-technical() sets the PI_LLM_WIKI_DIR context variable.
    # obsidian-wiki was removed along with obsidian.
    initExtra = ''
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

  programs.vivid = {
    enable = true;
    enableBashIntegration = true;
    activeTheme = "molokai";
  };
}
