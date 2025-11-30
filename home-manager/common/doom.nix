{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-doom-emacs-unstraightened.homeModule
  ];
  # services.emacs.enable = true;

  home.packages = with pkgs; [
    parinfer-rust-emacs
    coreutils-prefixed
  ];
  programs.doom-emacs = {
    enable = true;
    doomDir = ./doom.d;
  };
}
