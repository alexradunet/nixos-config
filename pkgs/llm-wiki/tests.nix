{
  buildNpmPackage,
  fetchNpmDeps,
}: let
  src = ./.;
in
  buildNpmPackage {
    pname = "llm-wiki-tests";
    version = "0.1.0";

    inherit src;

    npmDeps = fetchNpmDeps {
      inherit src;
      hash = "sha256-Hb6tMA4BBIMKIDwGoZmNb6fcjDkUNYhQsLsfOKEbGuc=";
    };

    dontNpmBuild = true;
    doCheck = true;

    checkPhase = ''
      runHook preCheck
      npm run test:ci
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      touch $out/passed
      runHook postInstall
    '';
  }
