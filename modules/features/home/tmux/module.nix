{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    sensibleOnTop = true;
    mouse = true;
    keyMode = "vi";
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;
    focusEvents = true;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g set-clipboard on
      set -g renumber-windows on
      set -as terminal-features ',xterm-256color:RGB'
      set -as terminal-features ',ghostty:RGB'

      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux config reloaded"
    '';
  };
}
