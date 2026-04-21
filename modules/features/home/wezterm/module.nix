{
  config,
  lib,
  pkgs,
  ...
}: let
  kwriteconfig = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
  kdeglobals = "${config.home.homeDirectory}/.config/kdeglobals";
in {
  home.sessionVariables.TERMINAL = "wezterm";

  programs.wezterm = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      audible_bell = "Disabled";
      check_for_updates = false;
      enable_wayland = true;
      hide_tab_bar_if_only_one_tab = true;
      use_fancy_tab_bar = false;
      scrollback_lines = 10000;
      adjust_window_size_when_changing_font_size = false;
      window_close_confirmation = "NeverPrompt";
      font = lib.generators.mkLuaInline ''wezterm.font("JetBrainsMono Nerd Font Mono")'';
      font_size = 12.5;
      window_padding = {
        left = 8;
        right = 8;
        top = 8;
        bottom = 8;
      };
    };
    extraConfig = ''
      config.ssh_domains = {
        {
          name = 'vps-nixos',
          remote_address = 'vps-nixos',
          username = 'alex',
          remote_wezterm_path = '/run/current-system/sw/bin/wezterm',
          multiplexing = 'WezTerm',
          assume_shell = 'Posix',
          local_echo_threshold_ms = 10,
        },
      }
    '';
  };

  home.activation.weztermDefaultTerminal = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.config"
    $DRY_RUN_CMD ${kwriteconfig} --file "${kdeglobals}" --group General --key TerminalApplication "wezterm"
    $DRY_RUN_CMD ${kwriteconfig} --file "${kdeglobals}" --group General --key TerminalService "org.wezfurlong.wezterm.desktop"
  '';
}
