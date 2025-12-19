_:

{
  wayland.windowManager.hyprland.settings = {
    env = [
      # Cursor configuration - scaled for HiDPI on Apple Silicon
      "XCURSOR_SIZE,32"
      "HYPRCURSOR_SIZE,32"

      # GTK scaling - use integer scale for compatibility
      # GDK_SCALE must be integer (1, 2, 3), so use 2 for HiDPI
      "GDK_SCALE,2"
      # GDK_DPI_SCALE adjusts fonts/text to compensate
      # 2 * 0.8 = 1.6 effective scale (good for Apple displays)
      "GDK_DPI_SCALE,0.8"

      # Qt scaling
      "QT_AUTO_SCREEN_SCALE_FACTOR,1"
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"

      # GTK theme - dark mode
      "GTK_THEME,Adwaita:dark"

      # Enable Wayland for Electron apps
      "ELECTRON_OZONE_PLATFORM_HINT,wayland"
    ];

    # Better HiDPI support for X11 apps
    xwayland.force_zero_scaling = true;
  };
}
