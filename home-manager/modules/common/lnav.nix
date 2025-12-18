{pkgs, ...}: {
  home.packages = [
    # pkgs.unstable.lnav
  ];
  home.sessionVariables = {
    # PAGER = "lnav -q";
  };
}
