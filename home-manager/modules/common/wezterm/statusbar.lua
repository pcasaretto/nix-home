-- Wezterm status bar configuration
-- Powerline-style with Catppuccin Macchiato colors

local wezterm = require("wezterm")

local M = {}

-- Catppuccin Macchiato colors
M.colors = {
  base = "#24273a",
  surface0 = "#363a4f",
  surface1 = "#494d64",
  surface2 = "#5b6078",
  text = "#cad3f5",
  subtext0 = "#a5adcb",
  blue = "#8aadf4",
  green = "#a6da95",
  yellow = "#eed49f",
  peach = "#f5a97f",
  mauve = "#c6a0f6",
  teal = "#8bd5ca",
  pink = "#f5bde6",
  red = "#ed8796",
}

-- Powerline symbols (pointing direction of flow)
M.SOLID_LEFT = wezterm.nerdfonts.pl_left_hard_divider   --
M.SOLID_RIGHT = wezterm.nerdfonts.pl_right_hard_divider --

-- Helper: shorten path with ~ for home
local function shorten_path(path)
  local home = os.getenv("HOME") or ""
  if home ~= "" and path:sub(1, #home) == home then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

-- Helper: get world-aware cwd display (Shopify tec gps)
local function get_world_cwd(cwd)
  local tec_path = os.getenv("HOME") .. "/.local/state/tec/profiles/base/current/global/bin/tec"
  local tec_ok, success, stdout = pcall(wezterm.run_child_process, {tec_path, "gps", "--json", cwd})
  if tec_ok and success and stdout and stdout ~= "" then
    local ok, gps = pcall(wezterm.json_parse, stdout)
    if ok and gps and gps.zone_path and gps.zone_path:match("^//") then
      local zone_path = gps.zone_path:gsub("^//", "")

      local parts = {}
      for part in zone_path:gmatch("[^/]+") do
        table.insert(parts, part)
      end
      local substrate = ""
      if #parts > 1 then
        local abbrev = {}
        for i = 1, #parts - 1 do
          table.insert(abbrev, parts[i]:sub(1, 1))
        end
        substrate = table.concat(abbrev, "/") .. "/" .. parts[#parts]
      elseif #parts == 1 then
        substrate = parts[1]
      end

      local project = ""
      if gps.path_in_zone and gps.path_in_zone ~= "" then
        local proj_parts = {}
        for part in gps.path_in_zone:gmatch("[^/]+") do
          table.insert(proj_parts, part)
        end
        if #proj_parts > 0 then
          project = "/" .. proj_parts[#proj_parts]
        end
      end

      return { text = " //" .. substrate .. project, is_world = true }
    end
  end
  return { text = shorten_path(cwd), is_world = false }
end

-- Helper: get git worktree name (replicating tmux-git-worktree logic)
local function get_git_worktree(path)
  local toplevel_success, toplevel_out = wezterm.run_child_process({
    "git", "-C", path, "rev-parse", "--show-toplevel"
  })
  if not toplevel_success then return "" end
  local current_path = toplevel_out:gsub("%s+$", "")

  local list_success, list_out = wezterm.run_child_process({
    "git", "-C", path, "worktree", "list", "--porcelain"
  })
  if not list_success or list_out == "" then return "" end

  local lines = {}
  for line in list_out:gmatch("[^\r\n]+") do
    table.insert(lines, line)
    if #lines >= 2 then break end
  end

  local first_two = (lines[1] or "") .. " " .. (lines[2] or "")
  if first_two:match("bare") then
    local parent_dir = current_path:match("(.+)/[^/]+$")
    if parent_dir then
      local parent_name = parent_dir:match("([^/]+)$")
      return "󰐅 " .. (parent_name or "")
    end
  else
    local main_worktree = (lines[1] or ""):match("^worktree (.+)$")
    if main_worktree and current_path ~= main_worktree then
      local worktree_name = current_path:match("([^/]+)$")
      return "󰐅 " .. (worktree_name or "")
    end
  end

  return ""
end

-- Helper: get battery info
local function get_battery()
  local battery_info = wezterm.battery_info()
  if #battery_info > 0 then
    local b = battery_info[1]
    local charge = math.floor(b.state_of_charge * 100 + 0.5)
    local icon = ""
    if charge >= 90 then icon = "󰁹"
    elseif charge >= 80 then icon = "󰂂"
    elseif charge >= 70 then icon = "󰂁"
    elseif charge >= 60 then icon = "󰂀"
    elseif charge >= 50 then icon = "󰁿"
    elseif charge >= 40 then icon = "󰁾"
    elseif charge >= 30 then icon = "󰁽"
    elseif charge >= 20 then icon = "󰁼"
    elseif charge >= 10 then icon = "󰁻"
    else icon = "󰁺"
    end
    return { icon = icon, charge = charge, state = b.state }
  end
  return nil
end

-- Setup status bar events
function M.setup()
  local colors = M.colors
  local SOLID_LEFT = M.SOLID_LEFT
  local SOLID_RIGHT = M.SOLID_RIGHT

  -- Status bar update event
  wezterm.on('update-status', function(window, pane)
    local cwd_url = pane:get_current_working_dir()

    -- Build left status with powerline segments
    local left_elements = {}

    if cwd_url then
      local cwd = cwd_url.file_path or tostring(cwd_url)
      local world_cwd = get_world_cwd(cwd)
      local worktree = get_git_worktree(cwd)

      -- CWD segment (blue or teal for world paths)
      local cwd_bg = world_cwd.is_world and colors.teal or colors.blue
      local cwd_icon = world_cwd.is_world and " 󰖟 " or "  "
      table.insert(left_elements, { Background = { Color = cwd_bg } })
      table.insert(left_elements, { Foreground = { Color = colors.base } })
      table.insert(left_elements, { Text = cwd_icon .. world_cwd.text .. " " })

      if worktree ~= "" then
        -- Worktree segment (mauve/purple)
        table.insert(left_elements, { Foreground = { Color = cwd_bg } })
        table.insert(left_elements, { Background = { Color = colors.mauve } })
        table.insert(left_elements, { Text = SOLID_LEFT })
        table.insert(left_elements, { Foreground = { Color = colors.base } })
        table.insert(left_elements, { Text = " " .. worktree .. " " })
        table.insert(left_elements, { Foreground = { Color = colors.mauve } })
      else
        table.insert(left_elements, { Foreground = { Color = cwd_bg } })
      end

      -- End cap
      table.insert(left_elements, { Background = { Color = "none" } })
      table.insert(left_elements, { Text = SOLID_LEFT })
    end

    window:set_left_status(wezterm.format(left_elements))

    -- Build right status with powerline segments
    local right_elements = {}
    local battery = get_battery()
    local datetime = wezterm.strftime("%H:%M")
    local date = wezterm.strftime("%Y-%m-%d")
    local hostname = wezterm.hostname():match("^([^%.]+)") or wezterm.hostname()

    -- Start cap for rightmost segment
    table.insert(right_elements, { Background = { Color = "none" } })
    table.insert(right_elements, { Foreground = { Color = colors.surface1 } })
    table.insert(right_elements, { Text = SOLID_RIGHT })

    -- Date segment (surface1)
    table.insert(right_elements, { Background = { Color = colors.surface1 } })
    table.insert(right_elements, { Foreground = { Color = colors.text } })
    table.insert(right_elements, { Text = " 󰃭 " .. date .. " " })

    -- Time segment (surface2)
    table.insert(right_elements, { Foreground = { Color = colors.surface2 } })
    table.insert(right_elements, { Background = { Color = colors.surface1 } })
    table.insert(right_elements, { Text = SOLID_RIGHT })
    table.insert(right_elements, { Background = { Color = colors.surface2 } })
    table.insert(right_elements, { Foreground = { Color = colors.text } })
    table.insert(right_elements, { Text = "  " .. datetime .. " " })

    -- Battery segment (green/yellow/red based on charge)
    if battery then
      local bat_color = colors.green
      if battery.charge < 20 then
        bat_color = colors.red
      elseif battery.charge < 40 then
        bat_color = colors.yellow
      end
      table.insert(right_elements, { Foreground = { Color = bat_color } })
      table.insert(right_elements, { Background = { Color = colors.surface2 } })
      table.insert(right_elements, { Text = SOLID_RIGHT })
      table.insert(right_elements, { Background = { Color = bat_color } })
      table.insert(right_elements, { Foreground = { Color = colors.base } })
      table.insert(right_elements, { Text = " " .. battery.icon .. " " .. battery.charge .. "%% " })

      -- Hostname segment (blue)
      table.insert(right_elements, { Foreground = { Color = colors.blue } })
      table.insert(right_elements, { Background = { Color = bat_color } })
    else
      -- Hostname segment (blue) - no battery
      table.insert(right_elements, { Foreground = { Color = colors.blue } })
      table.insert(right_elements, { Background = { Color = colors.surface2 } })
    end

    table.insert(right_elements, { Text = SOLID_RIGHT })
    table.insert(right_elements, { Background = { Color = colors.blue } })
    table.insert(right_elements, { Foreground = { Color = colors.base } })
    table.insert(right_elements, { Text = " 󰒋 " .. hostname .. " " })

    window:set_right_status(wezterm.format(right_elements))
  end)

  -- Tab formatting with colors
  wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
    local pane = tab.active_pane
    local process = pane.foreground_process_name or ""
    process = process:match("([^/]+)$") or process

    local index = tostring(tab.tab_index + 1)
    local zoom = pane.is_zoomed and " 󰍉" or ""

    local bg = tab.is_active and colors.surface2 or colors.surface0
    local fg = tab.is_active and colors.text or colors.subtext0
    local index_bg = tab.is_active and colors.green or colors.surface1

    return wezterm.format({
      { Background = { Color = "none" } },
      { Foreground = { Color = index_bg } },
      { Text = SOLID_RIGHT },
      { Background = { Color = index_bg } },
      { Foreground = { Color = colors.base } },
      { Text = " " .. index .. " " },
      { Background = { Color = bg } },
      { Foreground = { Color = index_bg } },
      { Text = SOLID_LEFT },
      { Foreground = { Color = fg } },
      { Text = " " .. process .. zoom .. " " },
      { Background = { Color = "none" } },
      { Foreground = { Color = bg } },
      { Text = SOLID_LEFT },
    })
  end)
end

return M
