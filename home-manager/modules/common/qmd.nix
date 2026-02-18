# QMD - local markdown search engine
{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    (inputs.qmd.packages.${pkgs.system}.default.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.python3
        pkgs.darwin.cctools
      ];
    }))
  ];
}
