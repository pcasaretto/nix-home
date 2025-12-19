{
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../../home-manager/common
    ../../../home-manager/linux
    ../../../home-manager/common/doom.nix
  ];

  home = {
    stateVersion = "23.05";
    sessionVariables = {};
    packages = with pkgs; [
      # Wayland utilities
      fuzzel              # App launcher
      wl-clipboard        # Clipboard utilities
      grim                # Screenshot utility
      slurp               # Region selector
      swayidle            # Idle management
      swaylock            # Screen locker

      # Applications
      chromium            # Web browser (ARM-compatible)

      # Additional useful tools
      networkmanagerapplet  # Network management
      brightnessctl         # Brightness control
      playerctl             # Media player control
    ];
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
}
