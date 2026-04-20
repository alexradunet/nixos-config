{...}: {
  services.power-profiles-daemon.enable = true;

  # nohang (new in 26.05): same OOM prevention as on the desktop,
  # especially valuable during long compile runs on battery.
  services.nohang.enable = true;
}
