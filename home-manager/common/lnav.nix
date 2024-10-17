{ pkgs, ... }: {
  home.packages = with pkgs; [
    lnav
  ];
  home.sessionVariables = {
    PAGER = "lnav -q";
  };
}
