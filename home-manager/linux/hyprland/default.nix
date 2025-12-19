{ pkgs, inputs, ... }:
let
  sys = pkgs.stdenv.hostPlatform.system;
in

{
  # Import all modular configuration files
  imports = [
    ./envs.nix
    ./input.nix
    ./outputs.nix
    ./layout.nix
    ./binds.nix
    ./startup.nix
    ./window-rules.nix
  ];

  # Hyprland window manager configuration
  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${sys}.hyprland;
    portalPackage = inputs.hyprland.packages.${sys}.xdg-desktop-portal-hyprland;
  };

  # Polkit authentication agent
  services.hyprpolkitagent.enable = true;

  # Waybar status bar
  programs.waybar.enable = true;
  catppuccin.waybar.enable = true;

  # Mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
    };
  };
  catppuccin.mako.enable = true;

  # Cursor themes for Hyprland
  home.packages = with pkgs; [
    bibata-cursors
    capitaine-cursors
    graphite-cursors
    numix-cursor-theme

    # Screenshot tools
    grim
    slurp

    # App launcher
    fuzzel
  ];
}
