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
      # new windows start in home, tabs/splits inherit current directory
      window-inherit-working-directory = false;
      working-directory = "home";

      # Performance settings
      window-vsync = true;
      # Clipboard settings
      clipboard-read = "allow";
      clipboard-write = "allow";
      copy-on-select = true;
    };
  };

  # Separate-instance config for herdr: inherits the base config and rebinds
  # the cmd keys to the tmux/herdr ctrl-b prefix sequences (same bytes as the
  # kitty setup). A second Ghostty process reads this file once at startup,
  # so the rebinds stay scoped to that instance. Launch it with the
  # `ghostty-herdr` shell function.
  xdg.configFile."ghostty-herdr/config".text = ''
    config-file = ${config.home.homeDirectory}/.config/ghostty/config

    keybind = cmd+t=text:\x02\x63
    keybind = cmd+d=text:\x02\x25
    keybind = cmd+shift+d=text:\x02\x22
    keybind = cmd+w=text:\x02\x60
    keybind = cmd+h=text:\x02\x80
    keybind = cmd+j=text:\x02\xa0
    keybind = cmd+k=text:\x02\xb0
    keybind = cmd+l=text:\x02\xc0
    keybind = cmd+1=text:\x02\x31
    keybind = cmd+2=text:\x02\x32
    keybind = cmd+3=text:\x02\x33
    keybind = cmd+4=text:\x02\x34
    keybind = cmd+5=text:\x02\x35
    keybind = cmd+6=text:\x02\x36
    keybind = cmd+7=text:\x02\x37
    keybind = cmd+8=text:\x02\x38
    keybind = cmd+9=text:\x02\x39
    keybind = alt+up=text:\x02\x1b[A
    keybind = alt+down=text:\x02\x1b[B
    keybind = alt+right=text:\x02\x1b[C
    keybind = alt+left=text:\x02\x1b[D
    keybind = cmd+shift+[=text:\x02\x70
    keybind = cmd+shift+]=text:\x02\x6e
    keybind = cmd+shift+enter=text:\x02\x7a
  '';
}
