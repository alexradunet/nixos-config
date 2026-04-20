{pkgs, ...}: {
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    tree
    unzip
    fastfetch
    eza
    gh
    chromium
    ffmpeg
    yt-dlp
    libsecret
  ];
}
