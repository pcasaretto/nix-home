{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:
stdenv.mkDerivation rec {
  pname = "wezterm-bin";
  version = "20260117-154428-05343b38";

  src = fetchurl {
    # Nightly rolling release; hash pins to a specific build.
    # To update: bump version (from zip directory name) and sha256.
    url = "https://github.com/wezterm/wezterm/releases/download/nightly/WezTerm-macos-nightly.zip";
    sha256 = "sha256-jVSmOUXvn+0d9vCweClXtFLeq7nvLQsEgq0y9plmq8E=";
  };

  nativeBuildInputs = [unzip];

  sourceRoot = "WezTerm-macos-${version}";

  # Don't strip or fixup the binaries - preserve the original code signature
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r WezTerm.app $out/Applications/

    # Create wrapper script for CLI access
    mkdir -p $out/bin
    ln -s $out/Applications/WezTerm.app/Contents/MacOS/wezterm $out/bin/wezterm
    ln -s $out/Applications/WezTerm.app/Contents/MacOS/wezterm-gui $out/bin/wezterm-gui
    ln -s $out/Applications/WezTerm.app/Contents/MacOS/wezterm-mux-server $out/bin/wezterm-mux-server
    ln -s $out/Applications/WezTerm.app/Contents/MacOS/strip-ansi-escapes $out/bin/strip-ansi-escapes

    # Install shell integration
    mkdir -p $out/etc/profile.d
    cp $out/Applications/WezTerm.app/Contents/Resources/wezterm.sh $out/etc/profile.d/

    # Install shell completions
    mkdir -p $out/share/bash-completion/completions
    mkdir -p $out/share/zsh/site-functions
    mkdir -p $out/share/fish/vendor_completions.d
    cp $out/Applications/WezTerm.app/Contents/Resources/shell-completion/bash $out/share/bash-completion/completions/wezterm
    cp $out/Applications/WezTerm.app/Contents/Resources/shell-completion/zsh $out/share/zsh/site-functions/_wezterm
    cp $out/Applications/WezTerm.app/Contents/Resources/shell-completion/fish $out/share/fish/vendor_completions.d/wezterm.fish

    runHook postInstall
  '';

  meta = with lib; {
    description = "GPU-accelerated cross-platform terminal emulator (pre-built binary with proper code signing)";
    homepage = "https://wezfurlong.org/wezterm/";
    license = licenses.mit;
    platforms = ["aarch64-darwin" "x86_64-darwin"];
    mainProgram = "wezterm";
  };
}
