{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    git
    neovim
    htop
    wget
    curl
    zellij
    pi
  ];
}
