{
  description = "My NixOS configurations";

  # Repo-local cache settings.
  # These apply as soon as someone uses this flake, which is helpful for
  # bootstrap/CI and not only after a host has already been rebuilt.
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    lib = nixpkgs.lib;

    # We only target x86_64-linux right now, but keeping outputs generated from
    # a system list makes it easier to add more systems later.
    supportedSystems = ["x86_64-linux"];
    forAllSystems = lib.genAttrs supportedSystems;

    # Export local packages through an overlay so the same package names are
    # available everywhere as pkgs.pi, pkgs.pi-web-access, and pkgs.llm-wiki.
    overlay = final: _prev: {
      pi = final.callPackage ./pkgs/pi {};
      pi-web-access = final.callPackage ./pkgs/pi-web-access {};
      llm-wiki = final.callPackage ./pkgs/llm-wiki {};
    };

    # Import nixpkgs for a specific target system with our local overlay applied.
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [overlay];
      };

    # Build a flake app from a package.
    # Prefer package.meta.mainProgram when present; otherwise fall back to the
    # package name so nix run knows which executable to start.
    mkApp = package: {
      type = "app";
      program = "${package}/bin/${package.meta.mainProgram or package.pname}";
      meta = {
        description = package.meta.description or package.pname;
      };
    };

    # Shared NixOS host constructor.
    # It injects the overlay, enables Home Manager, and combines the shared HM
    # config with a small host-specific Home Manager module.
    mkHost = system: path: homeModule:
      lib.nixosSystem {
        inherit system;
        modules = [
          {
            nixpkgs.overlays = [overlay];
          }
          path
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.alex = {
              imports = [
                ./home/alex.nix
                homeModule
              ];
            };
          }
        ];
      };
  in {
    overlays.default = overlay;

    # nix fmt looks for formatter.<system> and executes it.
    # We provide a tiny wrapper script instead of exposing Alejandra directly so
    # that plain `nix fmt` formats all writable .nix files in the repo.
    #
    # Why the shell command?
    # - `find ... -name '*.nix'` selects Nix files
    # - `-writable` skips files we cannot modify in this checkout
    # - `-print0 | xargs -0` safely handles paths with spaces/newlines
    # - when explicit args are passed, we forward them straight to Alejandra
    formatter = forAllSystems (
      system: let
        pkgs = pkgsFor system;
      in
        pkgs.writeShellApplication {
          name = "nixfmt";
          runtimeInputs = [pkgs.alejandra];
          text = ''
            if [ "$#" -eq 0 ]; then
              find . -type f -name '*.nix' -writable -print0 | xargs -0 alejandra
              exit 0
            fi

            exec alejandra "$@"
          '';
        }
    );

    # Dev shell with the formatter, two common Nix linters, and Node.js for
    # local llm-wiki test runs.
    devShells = forAllSystems (
      system: let
        pkgs = pkgsFor system;
      in {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            alejandra
            deadnix
            nodejs
            statix
          ];
        };
      }
    );

    checks = forAllSystems (
      system: let
        pkgs = pkgsFor system;
        alexHome = self.nixosConfigurations.pad-nixos.config.home-manager.users.alex.home;
        llmWikiActivation = self.nixosConfigurations.pad-nixos.config.home-manager.users.alex.home.activation.llmWikiStarter;
      in {
        formatting =
          pkgs.runCommand "formatting-check" {
            nativeBuildInputs = [pkgs.alejandra];
          } ''
            cd ${self}

            # CI/read-only formatting check.
            # `alejandra --check` fails if a file needs formatting but does not
            # rewrite anything.
            find . -type f -name '*.nix' -print0 \
              | xargs -0 alejandra --check

            # runCommand derivations must produce an output path on success.
            touch $out
          '';

        llm-wiki-tests = pkgs.callPackage ./pkgs/llm-wiki/tests.nix {};

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
    );

    packages = forAllSystems (
      system: let
        pkgs = pkgsFor system;
      in {
        pi = pkgs.pi;
        pi-web-access = pkgs.pi-web-access;
        llm-wiki = pkgs.llm-wiki;
        default = pkgs.pi;
      }
    );

    apps = forAllSystems (
      system: let
        pkgs = pkgsFor system;
        piApp = mkApp pkgs.pi;
      in {
        pi = piApp;
        default = piApp;
      }
    );

    nixosConfigurations = {
      # Mini PC / desktop workstation.
      evo-nixos = mkHost "x86_64-linux" ./hosts/evo-nixos ./home/hosts/evo-nixos.nix;

      # Canonical VPS / WireGuard hub.
      vps-nixos = mkHost "x86_64-linux" ./hosts/vps-nixos ./home/hosts/vps-nixos.nix;

      # Laptop profile.
      pad-nixos = mkHost "x86_64-linux" ./hosts/pad-nixos ./home/hosts/pad-nixos.nix;
    };
  };
}
