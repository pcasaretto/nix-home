{
  config,
  lib,
  pkgs,
  ...
}: {
  catppuccin.ghostty.enable = true;

  programs.ghostty = {
    enable = true;
    package = pkgs.unstable.ghostty-bin;
    settings = {
      # Font configuration
      font-family = "FiraCode Nerd Font Mono";
      font-size = 18;

      # working directory settings
      window-inherit-working-directory = false;
      working-directory = "home";

      # Performance settings
      window-vsync = true;

      # Clipboard settings
      clipboard-read = "allow";
      clipboard-write = "allow";
      copy-on-select = true;

      # Theme
      theme = "catppuccin-mocha";

      # Keybindings
      keybind = [
        # Tmux-style bindings
        "cmd+shift+d=text:\\x02\\x22"
        "cmd+d=text:\\x02\\x25"
        "cmd+w=text:\\x02\\x60"
        "cmd+h=text:\\x02\\x80"
        "cmd+j=text:\\x02\\xa0"
        "cmd+k=text:\\x02\\xb0"
        "cmd+l=text:\\x02\\xc0"
        "cmd+t=text:\\x02\\x63"

        # Number key bindings
        "cmd+1=text:\\x02\\x31"
        "cmd+2=text:\\x02\\x32"
        "cmd+3=text:\\x02\\x33"
        "cmd+4=text:\\x02\\x34"
        "cmd+5=text:\\x02\\x35"
        "cmd+6=text:\\x02\\x36"
        "cmd+7=text:\\x02\\x37"
        "cmd+8=text:\\x02\\x38"
        "cmd+9=text:\\x02\\x39"

        # Arrow key bindings
        "alt+up=text:\\x02\\x1b\\x5b\\x41"
        "alt+down=text:\\x02\\x1b\\x5b\\x42"
        "alt+right=text:\\x02\\x1b\\x5b\\x43"
        "alt+left=text:\\x02\\x1b\\x5b\\x44"

        # Bracket bindings
        "cmd+shift+left_bracket=text:\\x02\\x70"
        "cmd+shift+right_bracket=text:\\x02\\x6e"
        "cmd+shift+enter=text:\\x02\\x7a"
      ];
    };
  };
}
