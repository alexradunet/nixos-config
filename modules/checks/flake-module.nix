{
  config,
  inputs,
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
    piGuardrailsActivation = padConfig.home-manager.users.alex.home.activation.piGuardrails;
    nixosTests = lib.filterAttrs (_: lib.isDerivation) (pkgs.callPackage ../../tests/nixos {inherit config inputs;});
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
          session_var=${lib.escapeShellArg alexHome.sessionVariables.PI_LLM_WIKI_DIR}
          extension_source=${lib.escapeShellArg (toString alexHome.file.".pi/agent/extensions/llm-wiki".source)}
          activation_script=${lib.escapeShellArg llmWikiActivation.data}
          guardrails_activation=${lib.escapeShellArg piGuardrailsActivation.data}

          test "$session_var" = "/home/alex/Workspace/Knowledge"
          test -d "$extension_source"

          printf '%s\n' "$activation_script" | grep -F 'pages/projects' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'pages/resources/technical' >/dev/null
          printf '%s\n' "$activation_script" | grep -F 'templates/markdown' >/dev/null

          printf '%s\n' "$guardrails_activation" | grep -F '.pi/agent/guardrails.yaml' >/dev/null
          printf '%s\n' "$guardrails_activation" | grep -F 'guardrails.yaml' >/dev/null

          # Source-content checks for the PI runtime now live in the dedicated
          # NixOS VM smoke test (pi-runtime-smoke), which validates the files
          # after Home Manager activation on a booted machine.

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

          ! grep -Fq 'netbird-ui' ${../../modules/features/nixos/desktop/packages.nix}
          ! grep -Fq 'nvidiaBusId' ${../../modules/features/nixos/role-nvidia/module.nix}
          ! grep -Fq 'amdgpuBusId' ${../../modules/features/nixos/role-nvidia/module.nix}
          ! grep -Fq '10.77.0.0/24' ${../../modules/features/nixos/service-reaction/module.nix}

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
