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
    # Modern CLI replacements (added 2026-04-20)
    dua # interactive disk-usage analyser — faster than `du`
    procs # colourised `ps` with tree view and search
    bottom # GPU-aware `htop` replacement with charts
    qmd # hybrid BM25/vector search for markdown
  ];
}
