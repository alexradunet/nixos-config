{...}: {
  # NetBird client daemon — required for the netbird-ui tray icon to connect
  # to the NetBird overlay network. The UI package is pulled in via the desktop
  # packages module; this enables the background service that manages the tunnel.
  services.netbird.enable = true;
}
