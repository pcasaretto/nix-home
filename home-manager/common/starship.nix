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
      "$username"
      "[](bg:peach fg:red)"
      "$directory"
      "[](bg:yellow fg:peach)"
      ("$" + "{custom.git_branch_workaround}")
      "$git_status"
      "[](fg:yellow bg:green)"
      "$c"
      "$rust"
      "$golang"
      "$nodejs"
      "$php"
      "$java"
      "$kotlin"
      "$haskell"
      "$python"
      "[](fg:green bg:sapphire)"
      "$docker_context"
      "$conda"
      "[](fg:sapphire bg:lavender)"
      "$time"
      "[ ](fg:lavender)"
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

      username = {
        show_always = true;
        style_user = "bg:red fg:crust";
        style_root = "bg:red fg:crust";
        format = "[ $user ]($style)";
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
        git_branch_workaround = {
          command = "git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null";
          when = "git rev-parse --git-dir 2>/dev/null";
          symbol = "";
          style = "bg:yellow";
          format = "[[ $symbol $output ](fg:crust bg:yellow)]($style)";
        };
      };

      nodejs = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      c = {
        symbol = " ";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      java = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      kotlin = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      haskell = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      python = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:sapphire";
        format = "[[ $symbol( $context) ](fg:#83a598 bg:sapphire)]($style)";
      };

      conda = {
        style = "bg:sapphire";
        format = "[[ $symbol( $environment) ](fg:#83a598 bg:sapphire)]($style)";
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
