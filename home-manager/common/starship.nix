{ lib, config, ... }:
let
  inherit (config.catppuccin) sources;
  catppuccinFlavor = config.catppuccin.flavor;
in
 {
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
      "[](red)"
      "$os"
      "[](bg:peach fg:red)"
      ("$" + "{custom.world_path}")
      "[](bg:yellow fg:peach)"
      ("$" + "{custom.git_branch_workaround}")
      "$git_status"
      "[ ](fg:yellow)"
      "$cmd_duration"
      "$line_break"
      "$character"
      ];

      # palette = "catppuccin_${catppuccinFlavor}";

      os = {
        disabled = false;
        style = "bg:red fg:crust";
        symbols = {
          Windows = "󰍲";
          Ubuntu = "󰕈";
          SUSE = "";
          Raspbian = "󰐿";
          Mint = "󰣭";
          Macos = "󰀵";
          Manjaro = "";
          Linux = "󰌽";
          Gentoo = "󰣨";
          Fedora = "󰣛";
          Alpine = "";
          Amazon = "";
          Android = "";
          Arch = "󰣇";
          Artix = "󰣇";
          EndeavourOS = "";
          CentOS = "";
          Debian = "󰣚";
          Redhat = "󱄛";
          RedHatEnterprise = "󱄛";
          Pop = "";
        };
      };


      directory = {
        style = "bg:peach fg:crust";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = "󰝚 ";
          Pictures = " ";
          Developer = "󰲋 ";
        };
      };

      # Disabled: Using custom git_branch_workaround instead due to reftable issues
      # git_branch = {
      #   symbol = "";
      #   style = "bg:yellow";
      #   format = "[[ $symbol $branch ](fg:crust bg:yellow)]($style)";
      # };

      git_status = {
        style = "bg:yellow";
        format = "[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)";
      };

      # Temporary workaround for reftable compatibility - shells out to git
      custom = {
        world_path = {
          command = ''
            current="$PWD"
            # Check if we're in world monorepo
            while [[ "$current" != "/" ]]; do
              if [[ -f "$current/.meta/manifest.json" ]]; then
                rel_path="''${PWD#$current}"
                rel_path="''${rel_path#/}"  # Strip leading slash
                if [[ -z "$rel_path" ]]; then
                  echo "🌍 //"
                else
                  echo "🌍 //$rel_path"
                fi
                exit 0
              fi
              current="$(dirname "$current")"
            done
            # Not in world, show truncated directory path
            echo "$PWD" | sed "s|^$HOME|~|" | awk -F/ '{
              if (NF > 3) {
                printf "…/%s/%s\n", $(NF-1), $NF
              } else {
                print $0
              }
            }'
          '';
          when = "true";  # Always show
          symbol = "";
          style = "bg:peach";
          format = "[[ $output ](fg:crust bg:peach)]($style)";
        };
        git_branch_workaround = {
          command = "git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null";
          when = "git rev-parse --git-dir 2>/dev/null";
          symbol = "";
          style = "bg:yellow";
          format = "[[ $symbol $output ](fg:crust bg:yellow)]($style)";
        };
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:lavender";
        format = "[[  $time ](fg:crust bg:lavender)]($style)";
      };

      line_break.disabled = false;

      cmd_duration = {
        show_milliseconds = true;
        format = " in $duration ";
        style = "bg:lavender";
        disabled = false;
        show_notifications = false;
        min_time_to_notify = 45000;
      };

      character = {
        disabled = false;
        success_symbol = "[](bold fg:green)";
        error_symbol = "[](bold fg:red)";
        vimcmd_symbol = "[](bold fg:green)";
        vimcmd_replace_one_symbol = "[](bold fg:lavender)";
        vimcmd_replace_symbol = "[](bold fg:lavender)";
        vimcmd_visual_symbol = "[](bold fg:yellow)";
      };

      command_timeout = 500;  # 500ms for git commands in large repos
    };
    # // lib.importTOML "${sources.starship}/${catppuccinFlavor}.toml";
  };
  catppuccin.starship.enable = true;
}
