{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
}: let
  src = ./extension;
in
  buildNpmPackage {
    pname = "llm-wiki";
    version = "0.1.0";

    inherit src;

    npmDeps = fetchNpmDeps {
      inherit src;
      hash = "sha256-+LeWxRQkXOuVRHqg76p3DEdj7T9xEpUpohCY/G1tHGY=";
    };

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/llm-wiki
      cp -r . $out/share/llm-wiki/

      runHook postInstall
    '';

    meta = {
      description = "Pi extension for local wiki capture, search, scaffolding, and linting";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
