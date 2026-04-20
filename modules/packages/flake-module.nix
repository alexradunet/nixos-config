{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        (final: _prev: {
          pi = final.callPackage ../../pkgs/pi {};
          pi-web-access = final.callPackage ../../pkgs/pi-web-access {};
          llm-wiki = final.callPackage ../../pkgs/llm-wiki {};
          wg-admin = final.callPackage ../../pkgs/wg-admin {};
        })
      ];
    };

    formatter = pkgs.writeShellApplication {
      name = "nixfmt";
      runtimeInputs = [pkgs.alejandra];
      text = ''
        if [ "$#" -eq 0 ]; then
          find . -type f -name '*.nix' -writable -print0 | xargs -0 alejandra
          exit 0
        fi

        exec alejandra "$@"
      '';
    };

    devShells.default = pkgs.mkShellNoCC {
      packages = with pkgs; [
        age
        alejandra
        deadnix
        nodejs
        sops
        ssh-to-age
        statix
      ];
    };

    packages = {
      pi = pkgs.pi;
      pi-web-access = pkgs.pi-web-access;
      llm-wiki = pkgs.llm-wiki;
      wg-admin = pkgs.wg-admin;
      default = pkgs.pi;
    };

    apps = let
      mkApp = package: {
        type = "app";
        program = "${package}/bin/${package.meta.mainProgram or package.pname}";
        meta.description = package.meta.description or package.pname;
      };

      piApp = mkApp pkgs.pi;
    in {
      pi = piApp;
      default = piApp;
    };
  };

  flake.overlays.default = final: _prev: {
    pi = final.callPackage ../../pkgs/pi {};
    pi-web-access = final.callPackage ../../pkgs/pi-web-access {};
    llm-wiki = final.callPackage ../../pkgs/llm-wiki {};
    wg-admin = final.callPackage ../../pkgs/wg-admin {};
  };
}
