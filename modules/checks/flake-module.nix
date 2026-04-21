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
    padConfig = config.flake.nixosConfigurations.pad-nixos.config;
    evoConfig = config.flake.nixosConfigurations.evo-nixos.config;
    vpsConfig = config.flake.nixosConfigurations.vps-nixos.config;

    alexHome = padConfig.home-manager.users.alex.home;
    llmWikiActivation = padConfig.home-manager.users.alex.home.activation.wikiStarter;
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

          test "$session_var" = "/home/alex/NixPI/Knowledge"
          test -d "$extension_source"

          printf '%s\n' "$activation_script" | grep -F 'pages/projects/technical' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'pages/resources/technical/system-landscape.md' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'templates/obsidian/page.md' >/dev/null

          touch $out
        '';

        host-contracts = pkgs.runCommand "host-contracts-check" {} ''
          test '${evoConfig.networking.hostName}' = 'evo-nixos'
          test '${padConfig.networking.hostName}' = 'pad-nixos'
          test '${vpsConfig.networking.hostName}' = 'vps-nixos'

          test '${
            if evoConfig.networking.networkmanager.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.services.syncthing.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.services.displayManager.sddm.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.services.desktopManager.plasma6.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.services.pipewire.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.programs.steam.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.programs.steam.remotePlay.openFirewall
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.hardware.nvidia.open
            then "1"
            else "0"
          }' = '1'
          test '${
            if builtins.elem "nvidia" evoConfig.services.xserver.videoDrivers
            then "1"
            else "0"
          }' = '1'
          test '${
            if builtins.elem "nouveau" evoConfig.boot.blacklistedKernelModules
            then "1"
            else "0"
          }' = '1'
          test '${
            if builtins.elem "nvidiafb" evoConfig.boot.blacklistedKernelModules
            then "1"
            else "0"
          }' = '1'

          test '${
            if padConfig.services."power-profiles-daemon".enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if padConfig.services.reaction.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if padConfig.hardware.bluetooth.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if builtins.hasAttr "wg-admin" padConfig.services
            then "1"
            else "0"
          }' = '0'

          test '${
            if vpsConfig.services."wg-admin".enable
            then "1"
            else "0"
          }' = '1'
          test '${vpsConfig.services."wg-admin".stateDir}' = '/home/alex/.local/state/wg-admin'
          test '${
            if vpsConfig.services.openssh.openFirewall
            then "1"
            else "0"
          }' = '1'
          test '${
            if vpsConfig.networking.networkmanager.enable
            then "1"
            else "0"
          }' = '0'

          test '${
            if evoConfig.services.openssh.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if vpsConfig.users.users.alex.isNormalUser
            then "1"
            else "0"
          }' = '1'

          touch $out
        '';

        host-build-contracts = pkgs.runCommand "host-build-contracts-check" {} ''
          # Interpolating .name (a plain string) forces full Nix evaluation of each
          # toplevel derivation without requiring the .drv to already exist in the store.
          # Using .drvPath would fail for new derivations not yet computed locally.
          test -n '${config.flake.nixosConfigurations.evo-nixos.config.system.build.toplevel.name}'
          test -n '${config.flake.nixosConfigurations.pad-nixos.config.system.build.toplevel.name}'
          test -n '${config.flake.nixosConfigurations.vps-nixos.config.system.build.toplevel.name}'
          touch $out
        '';

        gaming-nvidia-contracts = pkgs.runCommand "gaming-nvidia-contracts-check" {} ''
          test '${
            if evoConfig.programs.steam.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.programs.steam.remotePlay.openFirewall
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.programs.steam.dedicatedServer.openFirewall
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.hardware.graphics.enable32Bit
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.hardware.nvidia.modesetting.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.hardware.nvidia.prime.offload.enable
            then "1"
            else "0"
          }' = '1'
          test '${
            if evoConfig.hardware.nvidia.nvidiaSettings
            then "1"
            else "0"
          }' = '1'
          touch $out
        '';
      }
      // nixosTests;
  };
}
