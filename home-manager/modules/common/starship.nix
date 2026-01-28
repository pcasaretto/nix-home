{
  lib,
  config,
  pkgs,
  ...
}: let
  # Read catppuccin colors from global palette
  flavor = config.catppuccin.flavor;
  palette = builtins.fromJSON (builtins.readFile "${config.catppuccin.sources.palette}/palette.json");
  colors = lib.mapAttrs (_: v: v.hex) palette.${flavor}.colors;
in {
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "$path"
        ("$" + "{custom.git_branch_workaround}")
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      git_status = {
        style = "bold yellow";
        format = "[$all_status$ahead_behind]($style) ";
      };

      custom = {
        path = {
          command = "echo $PWD | sed \"s|$HOME|~|\"";
          style = "${colors.teal}";
          format = "[$output]($style) ";
        };
        git_branch_workaround = {
          command = "git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null";
          when = "git rev-parse --git-dir 2>/dev/null";
          symbol = "";
          style = "bold purple";
          format = "on [$symbol$output]($style) ";
        };
      };

      cmd_duration = {
        format = "took [$duration]($style) ";
        style = "bold yellow";
        min_time = 2000;
      };

      character = {
        success_symbol = "[>](bold green)";
        error_symbol = "[>](bold red)";
      };

      line_break.disabled = false;

      command_timeout = 50;
    };
  };
  catppuccin.starship.enable = true;
}
