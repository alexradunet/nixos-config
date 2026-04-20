{
  config,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    alexHome = config.flake.nixosConfigurations.pad-nixos.config.home-manager.users.alex.home;
    llmWikiActivation = config.flake.nixosConfigurations.pad-nixos.config.home-manager.users.alex.home.activation.llmWikiStarter;
    nixosTests = lib.filterAttrs (_: lib.isDerivation) (pkgs.callPackage ../../tests/nixos {});
  in {
    checks =
      {
        formatting =
          pkgs.runCommand "formatting-check" {
            nativeBuildInputs = [pkgs.alejandra];
          } ''
            cd ${../..}

            find . -type f -name '*.nix' -print0 \
              | xargs -0 alejandra --check

            touch $out
          '';

        llm-wiki-tests = pkgs.callPackage ../../pkgs/llm-wiki/tests.nix {};

        llm-wiki-home = pkgs.runCommand "llm-wiki-home-check" {} ''
          session_var='${alexHome.sessionVariables.PI_LLM_WIKI_DIR}'
          extension_source='${alexHome.file.".pi/agent/extensions/llm-wiki".source}'
          activation_script='${llmWikiActivation.data}'

          test "$session_var" = "/home/alex/Sync/llm-wiki"
          test -d "$extension_source"

          printf '%s\n' "$activation_script" | grep -F 'pages/projects/technical' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'pages/areas/personal' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'pages/resources/technical/system-landscape.md' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'pages/journal/daily' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'templates/obsidian/daily-journal.md' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'templates/obsidian/page.md' >/dev/null

          touch $out
        '';
      }
      // nixosTests;
  };
}
