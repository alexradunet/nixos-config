{config, ...}: let
  alexHome = config.users.users.alex.home;
in {
  services.syncthing = {
    enable = true;
    user = "alex";
    dataDir = alexHome;
    configDir = "${alexHome}/.config/syncthing";
    openDefaultPorts = true;
  };
}
