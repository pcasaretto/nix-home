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

  worldPromptScript = pkgs.writeText "world-prompt.nu" ''
    #!/usr/bin/env nu

    # World prompt script for starship
    # Colors from catppuccin macchiato palette

    let gps = (do -i { tec gps --json } | from json)

    if ($gps | get -o zone_path | is-not-empty) {
      let green = (ansi { fg: "${colors.green}" })
      let teal = (ansi { fg: "${colors.teal}" })
      let reset = (ansi reset)

      let tree = $gps.tree_name

      let substrate = if ($gps.wroot_relative_path | is-not-empty) {
        let parts = ($gps.wroot_relative_path | split row "/")
        if ($parts | length) > 1 {
          let len = ($parts | length)
          let head_parts = ($parts | first ($len - 1))
          let abbrev = ($head_parts | each { $in | str substring 0..<1 } | str join "/")
          $"($abbrev)/($parts | last)"
        } else {
          $gps.wroot_relative_path
        }
      } else { "" }

      let project = if ($gps.path_in_zone | is-not-empty) {
        let parts = ($gps.path_in_zone | split row "/")
        $"/($parts | last)"
      } else { "" }

      $"🌍 ($green)+($tree)($reset)($teal)//($substrate)($project)($reset)"
    } else {
      ""
    }
  '';
in {
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        ("$" + "{custom.world_path}")
        ("$" + "{custom.regular_path}")
        "$git_branch"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      git_branch = {
        symbol = "";
        style = "bold purple";
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold yellow";
        format = "[$all_status$ahead_behind]($style) ";
      };

      custom = {
        world_path = {
          shell = ["${pkgs.unstable.nushell}/bin/nu" "-c"];
          command = "nu ${worldPromptScript}";
          when = ''tec gps --json 2>/dev/null | grep -q '"zone_path": "//' '';
          format = "$output ";
        };
        regular_path = {
          command = "echo $PWD | sed \"s|$HOME|~|\"";
          when = ''! tec gps --json 2>/dev/null | grep -q '"zone_path": "//' '';
          style = "${colors.teal}";
          format = "[$output]($style) ";
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
    };
  };
  catppuccin.starship.enable = true;
}
