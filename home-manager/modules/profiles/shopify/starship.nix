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
      ""
    }
  '';
in {
  programs.starship.settings = {
    # Override format to include world_path
    format = lib.mkForce (lib.concatStrings [
      ("$" + "{custom.world_path}")
      ("$" + "{custom.path}")
      ("$" + "{custom.git_branch_workaround}")
      "$git_status"
      "$cmd_duration"
      "$line_break"
      "$character"
    ]);

    custom = {
      world_path = {
        shell = ["${pkgs.unstable.nushell}/bin/nu" "-c"];
        command = "nu ${worldPromptScript}";
        when = ''tec gps --json 2>/dev/null | grep -q '"zone_path": "//' '';
        format = "$output ";
      };
      # Override path to only show outside world zones
      path.when = lib.mkForce ''! tec gps --json 2>/dev/null | grep -q '"zone_path": "//' '';
    };

    # tec gps can be slow
    command_timeout = lib.mkForce 200;
  };
}
