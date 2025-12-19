{ config, ... }:

{
  services.hyprpaper = {
    enable = true;

    settings = {
      ipc = "on";
      splash = false;

      # Preload wallpapers
      # You can change this path to your preferred wallpaper
      preload = [ "${config.home.homeDirectory}/.wallpaper.png" ];

      # Apply wallpaper to all monitors
      wallpaper = [
        ",${config.home.homeDirectory}/.wallpaper.png"
      ];
    };
  };
}
