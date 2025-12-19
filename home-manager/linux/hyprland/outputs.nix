_:

{
  wayland.windowManager.hyprland.settings = {
    monitor = [
      # Built-in display - auto configure with HiDPI scaling
      "eDP-1,preferred,auto,1.6"

      # Auto-configure any external monitors
      ",preferred,auto,1.6"
    ];

    # Turn off and lock when the lid is closed, but keep the session running
    bindl = [
      ", switch:on:Lid Switch, exec, sh -c \"(pidof hyprlock || hyprlock) && hyprctl keyword monitor 'eDP-1,disable' && hyprctl dispatch dpms off\""
      ", switch:off:Lid Switch, exec, sh -c \"hyprctl keyword monitor 'eDP-1,preferred,auto,1.6' && hyprctl dispatch dpms on\""
    ];
  };
}
