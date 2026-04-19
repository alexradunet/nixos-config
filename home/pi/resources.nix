{ ... }:

{ pkgs, ... }:

let
  piWebAccess = pkgs.callPackage ../../pkgs/pi-web-access { };
  piWebAccessRoot = "${piWebAccess}/share/pi-web-access";
in
{
  # Create the standard Pi global resource directories.
  # The directories stay writable for Pi and manual experimentation; only the
  # placeholder files are managed declaratively.
  home.file.".pi/agent/extensions/.keep".text = "";
  home.file.".pi/agent/prompts/.keep".text = "";
  home.file.".pi/agent/skills/.keep".text = "";
  home.file.".pi/agent/themes/.keep".text = "";

  # Bundle pi-web-access as a globally available Pi extension.
  home.file.".pi/agent/extensions/pi-web-access".source = piWebAccessRoot;
  home.file.".pi/agent/skills/librarian/SKILL.md".source =
    "${piWebAccessRoot}/skills/librarian/SKILL.md";
}
