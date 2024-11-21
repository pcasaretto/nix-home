{
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  ...
}: let
  dotenv = inputs.dotenv.packages.${pkgs.system}.default;
  transmission = pkgs.transmission_4.overrideAttrs { enableGTK = true; };
in {
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

    ./kitty.nix
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

  home.packages = with pkgs; [
    pkgs-x86.caffeine          # prevent mac from sleeping
    cyberduck                  # sftp client
    discord                    # chat
    hexfiend                   # hex editor
    m-cli                      # useful macOS CLI commands
    reattach-to-user-namespace # tmux helper
    rectangle                  # window manager
    # spotify                    # music
    slack                      # chat
    transmission               # torrent client
    vscode                     # code editor
    zoom-us                    # video conferencing
    _1password                 # password manager
    unstable.vlc-bin-universal # video player

    qemu
  ];
}
