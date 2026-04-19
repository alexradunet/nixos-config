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
}
