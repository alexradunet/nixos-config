{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
}: let
  src = ./extension;
in
  buildNpmPackage {
    pname = "pi-llm-wiki";
    version = "0.1.0";

    inherit src;

    npmDeps = fetchNpmDeps {
      inherit src;
      hash = "sha256-8uo9HJbM958g1dTEKoRc2GOS+QxiaocoFuSfXKl64WQ=";
    };

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/pi-llm-wiki
      cp -r . $out/share/pi-llm-wiki/

      runHook postInstall
    '';

    meta = {
      description = "Pi extension for local wiki capture, search, scaffolding, and linting";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
