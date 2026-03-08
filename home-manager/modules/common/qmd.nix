# QMD - local markdown search engine
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    (inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.python3
      ] ++ lib.optionals pkgs.stdenv.isDarwin [
        pkgs.darwin.cctools
      ];
    }))
  ];
}
