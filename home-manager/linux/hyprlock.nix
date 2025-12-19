_:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };

      auth = {
        fingerprint = {
          enabled = true;
        };
      };

      background = {
        monitor = "";
        color = "rgb(1e1e2e)";  # Catppuccin base
        blur_passes = 2;
        blur_size = 7;
        contrast = 0.89;
        brightness = 0.82;
        vibrancy = 0.17;
        vibrancy_darkness = 0.0;
      };

      label = [
        # Time
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(cdd6f4)";  # Catppuccin text
          font_size = 90;
          font_family = "SF Pro Display";
          position = "0, 80";
          halign = "center";
          valign = "center";
        }

        # Date
        {
          monitor = "";
          text = "cmd[update:1000] date +\"%A, %B %d\"";
          color = "rgb(bac2de)";  # Catppuccin subtext1
          font_size = 24;
          font_family = "SF Pro Display";
          position = "0, -10";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = {
        monitor = "";
        size = "300, 60";
        outline_thickness = 2;
        dots_size = 0.2;
        dots_spacing = 0.2;
        dots_center = true;
        outer_color = "rgb(c6a0f6)";  # Catppuccin mauve
        inner_color = "rgb(1e1e2e)";  # Catppuccin base
        font_color = "rgb(cdd6f4)";   # Catppuccin text
        check_color = "rgb(a6e3a1)";  # Catppuccin green
        fail_color = "rgb(f38ba8)";   # Catppuccin red
        fade_on_empty = false;
        placeholder_text = "<span foreground=\"##6c7086\">Password...</span>";
        hide_input = false;
        position = "0, -120";
        halign = "center";
        valign = "center";
      };
    };
  };
}
