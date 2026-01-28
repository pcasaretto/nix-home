# Shopify-specific starship prompt additions
# Overrides the common starship config to add world/zone path handling
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

  # Combined path script - handles both world zones and regular paths in one tec gps call
  pathPromptScript = pkgs.writeText "path-prompt.nu" ''
    #!/usr/bin/env nu

    # Path prompt script for starship
    # Shows world path when in a zone, regular path otherwise

    let gps = (do -i { tec gps --json } | from json)

    if ($gps | get -o zone_path | is-not-empty) and ($gps.zone_path | str starts-with "//") {
      let green = (ansi { fg: "${colors.green}" })
      let teal = (ansi { fg: "${colors.teal}" })
      let reset = (ansi reset)

      let tree = $gps.tree_name

      let substrate = if ($gps.zone_path | is-not-empty) {
        # zone_path is like "//.meta", extract the zone part after "//"
        let zone = ($gps.zone_path | str replace "//" "")
        if ($zone | is-not-empty) {
          let parts = ($zone | split row "/")
          if ($parts | length) > 1 {
            let len = ($parts | length)
            let head_parts = ($parts | first ($len - 1))
            let abbrev = ($head_parts | each { $in | str substring 0..<1 } | str join "/")
            $"($abbrev)/($parts | last)"
          } else {
            $zone
          }
        } else { "" }
      } else { "" }

      let project = if ($gps.path_in_zone | is-not-empty) {
        let parts = ($gps.path_in_zone | split row "/")
        $"/($parts | last)"
      } else { "" }

      $"🌍 ($green)+($tree)($reset)($teal)//($substrate)($project)($reset)"
    } else {
      # Not in a world zone - show abbreviated current directory
      let cyan = (ansi { fg: "${colors.sapphire}" })
      let reset = (ansi reset)
      let home = $env.HOME
      let cwd = (pwd)
      let display = if ($cwd | str starts-with $home) {
        $cwd | str replace $home "~"
      } else {
        $cwd
      }
      $"($cyan)($display)($reset)"
    }
  '';
in {
  programs.starship.settings = {
    # Override format - single path module handles both world zones and regular paths
    format = lib.mkForce (lib.concatStrings [
      ("$" + "{custom.path}")
      ("$" + "{custom.git_branch_workaround}")
      "$git_status"
      "$cmd_duration"
      "$line_break"
      "$character"
    ]);

    custom = {
      # Single path module - calls tec gps once, shows world path or regular path
      path = {
        shell = lib.mkForce ["${pkgs.unstable.nushell}/bin/nu" "-c"];
        command = lib.mkForce "nu ${pathPromptScript}";
        format = lib.mkForce "$output ";
      };
    };

    command_timeout = lib.mkForce 100;
  };
}
