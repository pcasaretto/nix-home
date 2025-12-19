{
  config,
  lib,
  pkgs,
  ...
}: {
  catppuccin.ghostty.enable = true;

  programs.ghostty = {
    enable = false;
    package = pkgs.unstable.ghostty-bin;
    settings = {
      # Font configuration
      font-family = "FiraCode Nerd Font Mono";
      font-size = 18;

      # working directory settings
      # new windows start in home, tabs/splits inherit current directory
      window-inherit-working-directory = true;
      working-directory = "home";

      # Performance settings
      window-vsync = true;

      # Clipboard settings
      clipboard-read = "allow";
      clipboard-write = "allow";
      copy-on-select = true;
    };
  };
}
