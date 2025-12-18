{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (config.catppuccin) sources;
  catppuccinFlavor = config.catppuccin.flavor;
in {
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
      # Written in nushell for compatibility
      custom = {
        world_path = {
          shell = ["${pkgs.nushell}/bin/nu" "-c"];
          command = "worldpath --compact --zsh";
          when = "";
          symbol = "";
          style = "bg:peach";
          format = "[[ $output ](fg:crust bg:peach)]($style)";
        };
        git_branch_workaround = {
          shell = ["${pkgs.nushell}/bin/nu" "-c"];
          command = "do -i { git symbolic-ref --short HEAD } | default (do -i { git rev-parse --short HEAD } | default '') | str trim";
          when = "git rev-parse --git-dir";
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

      command_timeout = 500; # 500ms for git commands in large repos
    };
    # // lib.importTOML "${sources.starship}/${catppuccinFlavor}.toml";
  };
  catppuccin.starship.enable = true;
}
