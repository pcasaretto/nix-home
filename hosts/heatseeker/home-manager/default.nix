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
    outputs.homeManagerModules.emacs

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../../home-manager/common
    ../../../home-manager/darwin

    ./kitty.nix
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

  modules.editors.emacs = {
    enable = true;
    default = true;
  };

  home.packages = with pkgs; [
    m-cli                      # useful macOS CLI commands
    reattach-to-user-namespace # tmux helper
    rectangle                  # window manager
    vscode                     # code editor
  ];
}