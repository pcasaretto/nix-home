_:

{
  wayland.windowManager.hyprland.settings = {
    # Set mod key to Super (Command key on Mac keyboards)
    "$mod" = "SUPER";

    # macOS-style keybindings
    bind = [
      # Window management (like macOS)
      "$mod, Q, killactive"                    # Cmd+Q to close window
      "$mod, W, killactive"                    # Cmd+W to close window (Mac users expect this)
      "$mod, F, fullscreen"                    # Cmd+F for fullscreen
      "$mod, M, fullscreen, 1"                 # Cmd+M for maximize (fake minimize)
      "$mod, H, togglespecialworkspace, hidden" # Cmd+H to hide window

      # Launch applications (like macOS Spotlight)
      "$mod, Space, exec, fuzzel"              # Cmd+Space for app launcher (like Spotlight)
      "$mod, Return, exec, kitty"              # Cmd+Return for terminal
      "$mod, T, exec, kitty"                   # Cmd+T for new terminal

      # Mission Control style - see all windows
      # Note: overview:toggle requires hyprland-overview plugin
      # "$mod, F3, overview:toggle"              # F3 for overview (if available)
      # "CTRL ALT, up, overview:toggle"          # Ctrl+Up for overview

      # Window navigation (like macOS but adapted)
      "$mod, Tab, cyclenext"                   # Cmd+Tab to cycle windows
      "$mod SHIFT, Tab, cyclenext, prev"       # Cmd+Shift+Tab to cycle backwards
      "$mod, grave, cyclenext, prev"           # Cmd+` to cycle same app windows

      # Move focus with arrow keys
      "$mod, left, movefocus, l"
      "$mod, right, movefocus, r"
      "$mod, up, movefocus, u"
      "$mod, down, movefocus, d"

      # Move focus with vim keys (bonus for efficiency)
      "$mod, H, movefocus, l"
      "$mod, L, movefocus, r"
      "$mod, K, movefocus, u"
      "$mod, J, movefocus, d"

      # Move windows
      "$mod SHIFT, left, movewindow, l"
      "$mod SHIFT, right, movewindow, r"
      "$mod SHIFT, up, movewindow, u"
      "$mod SHIFT, down, movewindow, d"

      # Switch workspaces (like macOS Spaces - Cmd+1, Cmd+2, etc.)
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"
      "$mod, 5, workspace, 5"
      "$mod, 6, workspace, 6"
      "$mod, 7, workspace, 7"
      "$mod, 8, workspace, 8"
      "$mod, 9, workspace, 9"
      "$mod, 0, workspace, 10"

      # Navigate workspaces like macOS Spaces (Ctrl+Left/Right)
      "CTRL, left, workspace, e-1"             # Ctrl+Left for previous workspace
      "CTRL, right, workspace, e+1"            # Ctrl+Right for next workspace

      # Move window to workspace
      "$mod SHIFT, 1, movetoworkspace, 1"
      "$mod SHIFT, 2, movetoworkspace, 2"
      "$mod SHIFT, 3, movetoworkspace, 3"
      "$mod SHIFT, 4, movetoworkspace, 4"
      "$mod SHIFT, 5, movetoworkspace, 5"
      "$mod SHIFT, 6, movetoworkspace, 6"
      "$mod SHIFT, 7, movetoworkspace, 7"
      "$mod SHIFT, 8, movetoworkspace, 8"
      "$mod SHIFT, 9, movetoworkspace, 9"
      "$mod SHIFT, 0, movetoworkspace, 10"

      # Keyboard backlight (like macOS F5/F6)
      ", XF86KbdBrightnessDown, exec, brightnessctl -d kbd_backlight set 10%-"
      ", XF86KbdBrightnessUp, exec, brightnessctl -d kbd_backlight set 10%+"

      # Screenshot (like macOS - Cmd+Shift+3/4)
      "$mod SHIFT, 3, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"  # Full screenshot
      "$mod SHIFT, 4, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"  # Region screenshot

      # Quick browser launch
      "$mod SHIFT, B, exec, chromium"

      # Window grouping/tabs
      "$mod, G, togglegroup"                   # Toggle window group/tabs
      "$mod, N, changegroupactive, f"          # Next tab in group
      "$mod, P, changegroupactive, b"          # Previous tab in group

      # Scratchpad/special workspace
      "$mod SHIFT, S, movetoworkspace, special:scratch"
      "$mod, S, togglespecialworkspace, scratch"
    ];

    # Mouse bindings
    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];
  };
}
