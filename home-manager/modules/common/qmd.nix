# QMD - local markdown search engine
# Note: qmd's Nix packaging is broken on Linux (tries to download during build)
# TODO: Report upstream at github:tobi/qmd
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  home.packages = lib.optionals pkgs.stdenv.isDarwin [
    (inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.python3
        pkgs.darwin.cctools
      ];
    }))
  ];
}
