_:

{
  wayland.windowManager.hyprland.settings = {
    # Using windowrulev2 for all rules (v1 is deprecated)

    windowrulev2 = [
      # Suppress maximize events (Hyprland uses tiling)
      "suppressevent maximize, class:.*"

      # Float file pickers
      "float, title:^(Open)$"
      "float, title:^(Save)$"
      "float, class:^(xdg-desktop-portal-gtk)$"

      # Float utility windows
      "float, class:^(pavucontrol)$"
      "float, class:^(blueberry.py)$"
      "float, class:^(nm-connection-editor)$"
      "float, class:^(blueman-manager)$"

      # Transparency for most windows (0.97 focused, 0.90 unfocused)
      "opacity 0.97 0.90, class:.*"

      # Opaque for media apps
      "opacity 1 1, class:^(vlc)$"
      "opacity 1 1, class:^(mpv)$"
      "opacity 1 1, title:^(Picture-in-Picture)$"

      # Opaque for browsers (better readability)
      "opacity 1 1, class:^(chromium)$"
      "opacity 1 1, class:^(google-chrome)$"
      "opacity 1 1, class:^(firefox)$"

      # Browser tags for advanced rules
      "tag +chromium-based-browser, class:((google-)?[cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable)"
      "tag +firefox-based-browser, class:([fF]irefox|zen|librewolf)"

      # Chrome/Chromium window management
      "tile, class:^(google-chrome)$"
      "tile, class:^(chromium)$"

      # Picture-in-Picture always on top and positioned in corner
      "float, title:^(Picture-in-Picture)$"
      "pin, title:^(Picture-in-Picture)$"
      "size 25% 25%, title:^(Picture-in-Picture)$"
      "move 74% 74%, title:^(Picture-in-Picture)$"

      # Idle inhibit for media players
      "idleinhibit focus, class:^(mpv)$"
      "idleinhibit focus, class:^(vlc)$"
      "idleinhibit fullscreen, class:^(chromium)$"
      "idleinhibit fullscreen, class:^(firefox)$"

      # Fix for some XWayland apps that spawn with no focus
      "nofocus, class:^$, title:^$, xwayland:1, floating:1, fullscreen:0, pinned:0"
    ];

    # Layer rules - blur syntax changed in recent Hyprland versions
    # Commented out until the correct syntax is determined
    # layerrule = [
    #   "blur, waybar"
    #   "blur, notifications"
    #   "blur, fuzzel"
    # ];
  };
}
