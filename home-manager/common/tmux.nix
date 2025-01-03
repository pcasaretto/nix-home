{
  config,
  lib,
  pkgs,
  ...
}: {
  catppuccin.tmux.enable = true;
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "tmux-256color";
    historyLimit = 10000;
    extraConfig = ''
      # Enable mouse movement
      set -g mouse on

      # Use system clipboard?
      set -g set-clipboard on

      # this removes ESC key delay
      set -s escape-time 0
    '';
  };
}
