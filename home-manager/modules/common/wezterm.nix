{...}: {
  xdg.configFile."wezterm/statusbar.lua".source = ./wezterm/statusbar.lua;

  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local config = wezterm.config_builder()

      local catppuccin = dofile(catppuccin_plugin)
      catppuccin.apply_to_config(config, catppuccin_config)
      config.font = wezterm.font("FiraCode Nerd Font Mono")
      config.font_size = 18

      config.default_cwd = wezterm.home_dir
      config.enable_kitty_keyboard = true

      -- Use retro tab bar for status line support
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = false

      -- Load status bar module
      local statusbar = dofile(wezterm.config_dir .. "/statusbar.lua")
      statusbar.setup()

      -- Only open links when CMD is held
      config.mouse_bindings = {
        -- CMD-click opens the link under the mouse cursor
        {
          event = { Up = { streak = 1, button = 'Left' } },
          mods = 'CMD',
          action = wezterm.action.OpenLinkAtMouseCursor,
        },
        -- Regular click just completes selection (no link opening)
        {
          event = { Up = { streak = 1, button = 'Left' } },
          mods = 'NONE',
          action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
        },
      }

      config.keys = {
        -- New window from home (not inherit cwd)
        {
          key = 'n',
          mods = 'CMD',
          action = wezterm.action.SpawnCommandInNewWindow {
            cwd = wezterm.home_dir,
          },
        },
        -- Split panes like iTerm
        {
          key = 'd',
          mods = 'CMD',
          action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
        },
        {
          key = 'd',
          mods = 'CMD|SHIFT',
          action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
        },
      }

      return config
    '';
  };

  catppuccin.wezterm.enable = true;
}
