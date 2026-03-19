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
        "$git_branch"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      git_branch = {
        style = "bold purple";
        format = "on [$symbol$branch]($style) ";
        symbol = "";
      };

      git_status = {
        style = "bold yellow";
        format = "[$all_status$ahead_behind]($style) ";
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
