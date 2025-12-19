_:

{
  wayland.windowManager.hyprland.settings = {
    # General window configuration
    general = {
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      "col.active_border" = "rgba(c6a0f6ff)";   # Purple (Catppuccin Mauve)
      "col.inactive_border" = "rgba(6c7086aa)"; # Gray
      layout = "dwindle";
      resize_on_border = true;  # Resize windows by dragging borders
    };

    # Decoration
    decoration = {
      rounding = 10;

      blur = {
        enabled = true;
        size = 5;
        passes = 2;
        new_optimizations = true;
        xray = false;
        ignore_opacity = false;
      };

      shadow = {
        enabled = true;
        range = 8;
        render_power = 2;
        color = "rgba(1a1a1a99)";
      };

      dim_inactive = false;
      dim_strength = 0.05;
    };

    # Animations with multiple bezier curves
    animations = {
      enabled = true;

      bezier = [
        "easeOutQuint,0.23,1,0.32,1"
        "easeInOutCubic,0.65,0,0.35,1"
        "quick,0.15,0,0.1,1"
      ];

      animation = [
        "windows,1,4,easeOutQuint,slide"
        "windowsOut,1,4,easeInOutCubic,slide"
        "border,1,10,default"
        "borderangle,1,8,default"
        "fade,1,3,quick"
        "workspaces,1,5,easeOutQuint,slidevert"
      ];
    };

    # Layout configuration - Dwindle
    dwindle = {
      pseudotile = true;
      preserve_split = true;
      force_split = 2;  # Always split to the right
      split_width_multiplier = 1.0;
    };

    # Master layout configuration
    master = {
      new_status = "master";
      new_on_top = false;
      mfact = 0.55;
      orientation = "center";  # Center single windows
    };

    # Window grouping/tabs configuration
    group = {
      "col.border_active" = "rgba(c6a0f6ff)";
      "col.border_inactive" = "rgba(6c7086aa)";
      "col.border_locked_active" = "rgba(c6a0f6ff)";
      "col.border_locked_inactive" = "rgba(6c7086aa)";

      groupbar = {
        font_size = 11;
        font_family = "monospace";
        height = 24;
        stacked = false;
        priority = 3;
        render_titles = true;
        scrolling = true;

        text_color = "rgba(cdd6f4ff)";        # Text color
        "col.active" = "rgba(c6a0f6dd)";      # Active tab
        "col.inactive" = "rgba(45475aaa)";    # Inactive tab
        "col.locked_active" = "rgba(f5c2e7dd)";
        "col.locked_inactive" = "rgba(313244aa)";

        gradients = false;
      };
    };

    # Misc settings
    misc = {
      disable_hyprland_logo = true;          # Clean, minimal like macOS
      disable_splash_rendering = true;
      force_default_wallpaper = 0;
      mouse_move_enables_dpms = true;        # Wake on mouse movement
      key_press_enables_dpms = true;         # Wake on key press
      vfr = true;                            # Variable refresh rate
      vrr = 1;                               # Adaptive sync
      enable_swallow = true;                 # Terminal swallowing
      swallow_regex = "^(kitty)$";
    };
  };
}
