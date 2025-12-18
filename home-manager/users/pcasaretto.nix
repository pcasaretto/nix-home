# Base user configuration shared between personal and work machines
# This module contains all common configuration that applies to both pcasaretto (personal) and paulo.casaretto (work)
{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [
    ../modules/common
    ../modules/darwin
    ../modules/darwin/mac-app-util.nix
    ../modules/common/doom.nix
  ];

  home.stateVersion = "23.05";

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

  programs.home-manager.enable = true;

  # Common packages for all machines
  home.packages = with pkgs; [
    m-cli
    rectangle
  ];
}
