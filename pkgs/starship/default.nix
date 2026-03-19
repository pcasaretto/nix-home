# Starship from master for reftable support (git_branch module)
# https://github.com/starship/starship/pull/7154
# Remove this once nixpkgs ships starship >= 1.25.0
{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
  writableTmpDirAsHomeHook,
  gitMinimal,
  buildPackages,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "starship";
  version = "1.25.0-unstable-2026-03-19";

  src = fetchFromGitHub {
    owner = "starship";
    repo = "starship";
    rev = "f0c75042d3dd194bbf6010828ae4504c67dbbe8a";
    hash = "sha256-fWeeUbVM6Hax1IFup5BApEr9+NTDV12fppvyN2CZIx8=";
  };

  nativeBuildInputs = [ installShellFiles ];

  buildInputs = lib.optionals (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) [
    writableTmpDirAsHomeHook
  ];

  postInstall = ''
    presetdir=$out/share/starship/presets/
    mkdir -p $presetdir
    cp docs/public/presets/toml/*.toml $presetdir
  ''
  + lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) (
    let
      emulator = stdenv.hostPlatform.emulator buildPackages;
    in
    ''
      installShellCompletion --cmd starship \
        --bash <(${emulator} $out/bin/starship completions bash) \
        --fish <(${emulator} $out/bin/starship completions fish) \
        --zsh <(${emulator} $out/bin/starship completions zsh)
    ''
  );

  cargoHash = "sha256-s3ipfZ3cjUNKfNpsnL122Hnv8MrBCDg1/AqteAvzwYw=";

  nativeCheckInputs = [
    gitMinimal
    writableTmpDirAsHomeHook
  ];

  meta = {
    description = "Minimal, blazing fast, and extremely customizable prompt for any shell";
    homepage = "https://starship.rs";
    license = lib.licenses.isc;
    mainProgram = "starship";
  };
})
