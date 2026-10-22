# Base user configuration shared between personal and work machines
# This module contains all common configuration that applies to both pcasaretto (personal) and paulo.casaretto (work)
# It evaluates on macOS and Linux: macOS-only settings are gated on Darwin.
{
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in {
  imports = [
    ../modules/common
    ../modules/darwin # no-op on Linux
    ../modules/darwin/mac-app-util.nix # disables itself on Linux
    ../modules/common/doom.nix
  ];

  home.stateVersion = "23.05";

  # Disable Home Manager's generated manpage to avoid an upstream
  # options.json store-path context warning during evaluation.
  manual.manpages.enable = false;

  nixpkgs = {
    overlays =
      builtins.attrValues outputs.overlays
      ++ [
        outputs.overlays.apple-silicon
      ];
    config = {
      allowUnfree = true;
    };
  };

  # 1Password SSH agent (macOS socket path)
  home.sessionVariables = lib.mkIf isDarwin {
    SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

  # Neovim
  catppuccin.nvim.enable = true;
  programs.neovim = {
    enable = true;
    # Keep the pre-26.05 defaults explicit while home.stateVersion is older.
    withRuby = true;
    withPython3 = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig
      nvim-treesitter
      plenary-nvim
      mini-nvim
    ];
    extraConfig = ''
      set clipboard=unnamedplus
    '';
  };

  programs.home-manager.enable = true;

  # macOS utilities
  home.packages = lib.optionals isDarwin (with pkgs; [
    m-cli
    rectangle
  ]);
}
