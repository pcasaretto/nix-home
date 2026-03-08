{
  lib,
  stdenv,
  fetchurl,
  unzip,
  xz,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  # Linux dependencies
  openssl,
  fontconfig,
  wayland,
  libxkbcommon,
  libGL,
  xorg,
  vulkan-loader,
  libgcc,
}:
let
  version = "20240203-110809-5046fc22";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/wez/wezterm/releases/download/${version}/WezTerm-macos-${version}.zip";
      hash = "sha256-53OIytVfLp2pWiIKiSBqbFj4ZYdKYpt8PqPBYvVpIiQ=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/wez/wezterm/releases/download/${version}/WezTerm-macos-${version}.zip";
      hash = "sha256-53OIytVfLp2pWiIKiSBqbFj4ZYdKYpt8PqPBYvVpIiQ=";
    };
    "x86_64-linux" = {
      url = "https://github.com/wezterm/wezterm/releases/download/${version}/wezterm-${version}.Ubuntu22.04.tar.xz";
      hash = "sha256-FCy0beZIIAuFLMSx2TLmuPKp08VfbcWvRLbU7rk4X1w=";
    };
    "aarch64-linux" = {
      url = "https://github.com/wezterm/wezterm/releases/download/${version}/wezterm-${version}.Ubuntu22.04.arm64.deb";
      hash = "sha256-PmTmGGAfJUeV99GKQdjdonCS3cTn+R4BdJIVbEj5eYs=";
    };
  };

  src = fetchurl {
    inherit (sources.${stdenv.hostPlatform.system}) url hash;
  };

  # Linux runtime dependencies
  linuxLibs = [
    openssl
    fontconfig
    wayland
    libxkbcommon
    libGL
    xorg.libX11
    xorg.libxcb
    xorg.libXcursor
    xorg.xcbutilwm
    xorg.xcbutilimage
    vulkan-loader
    libgcc.lib
  ];
in
stdenv.mkDerivation {
  pname = "wezterm-bin";
  inherit version src;

  nativeBuildInputs =
    lib.optionals stdenv.isDarwin [unzip]
    ++ lib.optionals stdenv.isLinux [
      xz
      autoPatchelfHook
      makeWrapper
    ]
    ++ lib.optionals (stdenv.isLinux && stdenv.isAarch64) [dpkg];

  buildInputs = lib.optionals stdenv.isLinux linuxLibs;

  sourceRoot = lib.optionalString stdenv.isDarwin "WezTerm-macos-${version}";

  unpackPhase = lib.optionalString (stdenv.isLinux && stdenv.isAarch64) ''
    dpkg-deb -x $src .
  '';

  # Don't strip or fixup the binaries on macOS - preserve the original code signature
  dontStrip = stdenv.isDarwin;
  dontFixup = stdenv.isDarwin;

  installPhase =
    if stdenv.isDarwin then ''
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
    '' else ''
      runHook preInstall

      # Handle both tar.xz and deb extraction structures
      if [ -d wezterm ]; then
        cd wezterm
      fi

      mkdir -p $out
      cp -r usr/bin $out/
      cp -r usr/share $out/

      # Wrap binaries with library path
      for bin in $out/bin/*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then
          wrapProgram "$bin" \
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath linuxLibs}"
        fi
      done

      runHook postInstall
    '';

  meta = with lib; {
    description = "GPU-accelerated cross-platform terminal emulator (pre-built binary)";
    homepage = "https://wezfurlong.org/wezterm/";
    license = licenses.mit;
    platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    mainProgram = "wezterm";
  };
}
