# Wezterm plugins module for home-manager
#
# This module allows declarative management of wezterm plugins via Nix.
# Plugins are linked into wezterm's plugin cache directory, so
# wezterm.plugin.require() finds them locally instead of downloading.
#
# Usage:
#   programs.wezterm.plugins = [
#     {
#       url = "https://github.com/michaelbrusegard/tabline.wez";
#       src = inputs.tabline-wez;  # or fetchFromGitHub { ... }
#     }
#   ];
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.wezterm;

  # Encode a URL to wezterm's plugin directory naming scheme
  # wezterm replaces special characters: : -> C, / -> Z, . -> D, - -> s
  encodePluginUrl = url:
    builtins.replaceStrings
    [":" "/" "." "-"]
    ["C" "Z" "D" "s"]
    url;

  # Generate home.file entries for each plugin
  pluginFiles = listToAttrs (map (plugin: {
      name = ".local/share/wezterm/plugins/${encodePluginUrl plugin.url}/plugin";
      value = {source = "${plugin.src}/plugin";};
    })
    cfg.plugins);
in {
  options.programs.wezterm.plugins = mkOption {
    type = types.listOf (types.submodule {
      options = {
        url = mkOption {
          type = types.str;
          description = "The plugin URL as used in wezterm.plugin.require()";
          example = "https://github.com/michaelbrusegard/tabline.wez";
        };
        src = mkOption {
          type = types.path;
          description = "The plugin source (flake input or fetchFromGitHub)";
          example = "inputs.tabline-wez";
        };
      };
    });
    default = [];
    description = ''
      List of wezterm plugins to install. Each plugin needs:
      - url: The URL used in wezterm.plugin.require()
      - src: A Nix path to the plugin source (flake input or fetchFromGitHub)

      Plugins are linked into ~/.local/share/wezterm/plugins/ so wezterm
      finds them locally without downloading.
    '';
    example = literalExpression ''
      [
        {
          url = "https://github.com/michaelbrusegard/tabline.wez";
          src = inputs.tabline-wez;
        }
        {
          url = "https://github.com/adriankarlen/bar.wezterm";
          src = pkgs.fetchFromGitHub {
            owner = "adriankarlen";
            repo = "bar.wezterm";
            rev = "main";
            hash = "sha256-AAAA...";
          };
        }
      ]
    '';
  };

  config = mkIf (cfg.enable && cfg.plugins != []) {
    home.file = pluginFiles;
  };
}
