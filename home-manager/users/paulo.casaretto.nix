# User configuration for paulo.casaretto (Shopify work machine)
# Activate with: home-manager switch --flake .#paulo.casaretto
{
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Platform modules
    ../modules/common
    ../modules/darwin
    ../modules/darwin/mac-app-util.nix

    # Programs
    ../modules/common/doom.nix

    # Work profile
    ../modules/profiles/shopify.nix
  ];

  # Identity
  home.username = "paulo.casaretto";
  home.homeDirectory = "/Users/paulo.casaretto";
  home.stateVersion = "23.05";

  # Nixpkgs configuration
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

  # 1Password SSH agent
  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

  # Neovim
  catppuccin.nvim.enable = true;
  programs.neovim = {
    enable = true;
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

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Packages
  home.packages = with pkgs; [
    m-cli # useful macOS CLI commands
    rectangle # window manager
    uv # python package manager
  ];
}
