# Standalone home-manager configuration for heatseeker (work machine)
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
    ../common
    ../darwin
    ../darwin/mac-app-util.nix
    ../common/doom.nix
  ];

  # Required for standalone home-manager
  home.username = "paulo.casaretto";
  home.homeDirectory = "/Users/paulo.casaretto";
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

  # Heatseeker-specific: Shopify dev environment
  programs.zsh.shellAliases = {
    ls = "wls";
    cd = "wcd";
  };

  programs.zsh.initContent = ''
    [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh
    [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
    [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
    # Added by //areas/tools/world-up
    [[ -x ~/world/.tectonix/init ]] && eval "$(~/world/.tectonix/init zsh)"
    # Added by tec agent
    [[ -x /Users/paulo.casaretto/.local/state/tec/profiles/base/current/global/init ]] && eval "$(/Users/paulo.casaretto/.local/state/tec/profiles/base/current/global/init zsh)"
  '';

  # Heatseeker-specific: Shopify git email
  programs.git.userEmail = "paulo.casaretto@shopify.com";

  # Neovim configuration
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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Heatseeker-specific packages
  home.packages = with pkgs; [
    m-cli # useful macOS CLI commands
    rectangle # window manager
    uv # python package manager
  ];
}
