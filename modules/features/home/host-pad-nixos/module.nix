{lib, ...}: {
  programs.wezterm.extraConfig = lib.mkAfter ''
    config.ssh_domains = config.ssh_domains or {}
    table.insert(config.ssh_domains, {
      name = 'vps-nixos',
      remote_address = 'vps-nixos',
      username = 'alex',
      remote_wezterm_path = '/run/current-system/sw/bin/wezterm',
      multiplexing = 'WezTerm',
      assume_shell = 'Posix',
      local_echo_threshold_ms = 10,
    })
  '';
}
