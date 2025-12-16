
{ inputs, pkgs, ... }: {
  imports = [
    inputs.nix-doom-emacs-unstraightened.homeModule
  ];
  # services.emacs.enable = true;
  programs.doom-emacs = {
    enable = true;
    doomDir = ./doom.d;
  };

  # for "gls"
  home.packages = [
    pkgs.coreutils-prefixed
  ];

}
