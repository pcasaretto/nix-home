# QMD - local markdown search engine
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  home.packages = [
    (inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      # node-gyp compiles better-sqlite3: python3 everywhere, plus the
      # cctools toolchain on macOS.
      nativeBuildInputs =
        old.nativeBuildInputs
        ++ [pkgs.python3]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [pkgs.darwin.cctools];
    }))
  ];
}
