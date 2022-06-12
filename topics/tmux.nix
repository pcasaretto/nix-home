{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    extraConfig = ''
            set -g mouse on
    '';
  };
}
