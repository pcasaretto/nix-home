{
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  home.stateVersion = "23.05";

  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../../home-manager/common
    ../../../home-manager/darwin
    ../../../home-manager/darwin/mac-app-util.nix
    ../../../home-manager/common/doom.nix

    ./dev.nix
    ./git.nix
  ];

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays ++ [
      outputs.overlays.apple-silicon
    ];
    config = {
      allowUnfree = true;
    };
  };

  home.sessionVariables = {
    # use 1password agent for ssh
    SSH_AUTH_SOCK = "\$HOME/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

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

  home.packages = with pkgs; [
    m-cli                      # useful macOS CLI commands
    rectangle                  # window manager
    uv                         # python package manager
  ];
}
