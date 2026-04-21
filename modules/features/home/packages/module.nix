{pkgs, ...}: {
  # Set a writable npm global prefix so `npm install -g` (used by `pi install`)
  # doesn't try to write into the read-only nix store.
  home.file.".npmrc".text = ''
    prefix = /home/alex/.npm-global
  '';
  home.sessionPath = [ "/home/alex/.npm-global/bin" ];

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
    nodejs # node + npm, needed for `pi install npm:...`
  ];
}
