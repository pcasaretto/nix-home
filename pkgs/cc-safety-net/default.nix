{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "cc-safety-net";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "kenryu42";
    repo = "claude-code-safety-net";
    rev = "v${version}";
    hash = "sha256-nRItuQ4OMD0DB4QdXo2H0MDW0ATq6Xc0b2Z6vrfd1sQ=";
  };

  nativeBuildInputs = [makeWrapper];

  # The dist directory is pre-built in the repo
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/cc-safety-net
    cp -r dist $out/lib/cc-safety-net/

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/cc-safety-net \
      --add-flags "$out/lib/cc-safety-net/dist/bin/cc-safety-net.js"

    # Include commands for Claude Code integration
    mkdir -p $out/share/cc-safety-net
    cp -r commands $out/share/cc-safety-net/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code plugin - block destructive git and filesystem commands";
    homepage = "https://github.com/kenryu42/claude-code-safety-net";
    license = licenses.mit;
    mainProgram = "cc-safety-net";
  };
}
