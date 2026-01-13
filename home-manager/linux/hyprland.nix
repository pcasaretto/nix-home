{ ... }:

{
  # Import modular Hyprland configuration
  imports = [
    ./hyprland        # Main Hyprland config with all modules
    ./hypridle.nix    # Power management and screen locking
    ./hyprlock.nix    # Screen locker
    ./hyprpaper.nix   # Wallpaper manager
  ];
}
