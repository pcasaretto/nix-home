
{ inputs, ... }: {
  imports = [
    inputs.nix-doom-emacs-unstraightened.homeModule
  ];
  # services.emacs.enable = true;
  programs.doom-emacs = {
    enable = true;
    doomDir = ./doom.d;
  };
}