{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "knowledge-publisher";
  version = "0.1.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "Local qmd + Quick publisher for ~/knowledge";
    license = licenses.mit;
    mainProgram = "knowledge-publisher";
    platforms = platforms.darwin;
  };
}
