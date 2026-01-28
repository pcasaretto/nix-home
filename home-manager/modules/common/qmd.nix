# QMD - local markdown search engine
{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.qmd.packages.${pkgs.system}.default
  ];
}
