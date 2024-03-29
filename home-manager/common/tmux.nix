{
  config,
  lib,
  pkgs,
  ...
}: {
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

      # Powerline green theme

      # Status update interval
      set -g status-interval 1

      # Basic status bar colors
      set -g status-style fg=colour240,bg=colour233

      # Left side of status bar
      set -g status-left-style bg=colour233,fg=colour243
      set -g status-left-length 40
      set -g status-left "#[fg=colour232,bg=colour100,bold] #S #[fg=colour100,bg=colour240,nobold]#[fg=colour233,bg=colour240] #(whoami) #[fg=colour240,bg=colour235]#[fg=colour240,bg=colour235] #I:#P #[fg=colour235,bg=colour233,nobold]"

      # Right side of status bar
      set -g status-right-style bg=colour233,fg=colour243
      set -g status-right-length 150
      set -g status-right "#[fg=colour235,bg=colour233]#[fg=colour240,bg=colour235] %H:%M:%S #[fg=colour240,bg=colour235]#[fg=colour233,bg=colour240] %d-%b-%y #[fg=colour245,bg=colour240]#[fg=colour232,bg=colour245,bold] #H "

      # Window status
      set -g window-status-format " #I:#W#F "
      set -g window-status-current-format " #I:#W#F "

      # Current window status
      set -g window-status-current-style bg=colour100,fg=colour232

      # Window with activity status
      set -g window-status-activity-style bg=colour107,fg=colour233 # fg and bg are flipped here due to
      # a bug in tmux

      # Window separator
      set -g window-status-separator ""

      # Window status alignment
      set -g status-justify centre

      # Pane border
      set -g pane-border-style bg=default,fg=colour238

      # Active pane border
      set -g pane-active-border-style bg=default,fg=colour100

      # Pane number indicator
      set -g display-panes-colour colour233
      set -g display-panes-active-colour colour245

      # Clock mode
      set -g clock-mode-colour colour100
      set -g clock-mode-style 24

      # Message
      set -g message-style bg=colour100,fg=black

      # Command message
      set -g message-command-style bg=colour233,fg=black

      # Mode
      set -g mode-style bg=colour100,fg=colour235
    '';
  };
}
