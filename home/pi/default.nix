{...}: {
  # Pi global resource skeleton.
  # We keep Pi's default config root (~/.pi/agent) and manage the resource
  # directories declaratively, while leaving Pi's mutable state files alone.
  imports = [
    ./resources.nix
  ];
}
