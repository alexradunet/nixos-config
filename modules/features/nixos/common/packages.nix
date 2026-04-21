{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    git
    neovim
    htop
    wget
    curl
    pi
    age
    ssh-to-age
    sops
  ];
}
