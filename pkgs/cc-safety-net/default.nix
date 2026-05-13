{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "cc-safety-net";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "kenryu42";
    repo = "claude-code-safety-net";
    rev = "v${version}";
    hash = "sha256-1cQDwAqGoiWY4Cf8RRxRj70x+1ntjanGvLbx2hcBKec=";
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

    # Include optional integration resources. v0.9.0 migrated the Claude Code
    # helpers from commands/ to skills/, but keep an empty commands directory so
    # older local config paths don't fail if they still reference it.
    mkdir -p $out/share/cc-safety-net/commands
    for dir in assets hooks skills; do
      if [ -d "$dir" ]; then
        cp -r "$dir" $out/share/cc-safety-net/
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code plugin - block destructive git and filesystem commands";
    homepage = "https://github.com/kenryu42/claude-code-safety-net";
    license = licenses.mit;
    mainProgram = "cc-safety-net";
  };
}
