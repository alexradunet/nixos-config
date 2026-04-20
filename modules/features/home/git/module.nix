{...}: {
  programs.git = {
    enable = true;

    settings = {
      user.name = "alex";
      user.email = "dev@alexradu.net";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
    };
  };

  # delta: syntax-highlighted, side-by-side diffs with line numbers.
  # Since current home-manager, this lives under programs.delta (not programs.git.delta).
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n/N to move between diff sections
      side-by-side = true;
      line-numbers = true;
    };
  };
}
