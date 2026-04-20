{...}: {
  flake.homeModules.alex = {
    home.username = "alex";
    home.homeDirectory = "/home/alex";
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;
  };
}
