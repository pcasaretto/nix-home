_:

{
  wayland.windowManager.hyprland.settings = {
    # Input configuration
    input = {
      kb_layout = "us";
      kb_options = "ctrl:nocaps";  # Remap Caps Lock to Control
      follow_mouse = 1;

      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
        tap-to-click = true;
        clickfinger_behavior = true;  # Two-finger right-click, three-finger middle-click
      };

      sensitivity = 0;  # -1.0 to 1.0, 0 means no modification
      accel_profile = "adaptive";
    };

    # Gestures (macOS-like trackpad gestures)
    # Note: Hyprland 0.51+ uses new gesture syntax
    gestures = {
      # 3-finger horizontal swipe for workspace switching (like macOS Spaces)
      gesture = "3, horizontal, workspace";

      # Additional gesture settings
      workspace_swipe_distance = 300;
      workspace_swipe_invert = true;         # Match macOS direction
      workspace_swipe_min_speed_to_force = 30;
      workspace_swipe_cancel_ratio = 0.5;
      workspace_swipe_create_new = true;     # Create new workspaces when swiping past last one
    };
  };
}
