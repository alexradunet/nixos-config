{ ... }:

{
  # Create the standard Pi global resource directories.
  # The directories stay writable for Pi and manual experimentation; only the
  # placeholder files are managed declaratively.
  home.file.".pi/agent/extensions/.keep".text = "";
  home.file.".pi/agent/prompts/.keep".text = "";
  home.file.".pi/agent/skills/.keep".text = "";
  home.file.".pi/agent/themes/.keep".text = "";
}
