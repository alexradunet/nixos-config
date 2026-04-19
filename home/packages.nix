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

    # Pi / pi-web-access runtime helpers
    chromium
    ffmpeg
    yt-dlp
    libsecret
  ];
}
