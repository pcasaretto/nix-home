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
    ./git.nix
    ./kitty.nix
    ./tmux.nix
    ./zsh.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.apple-silicon

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # Direnv, load and unload environment variables depending on the current directory.
  # https://direnv.net
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Htop
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.htop.enable
  programs.htop.enable = true;
  programs.htop.settings.show_program_path = true;

  modules.editors.emacs = {
    enable = true;
    default = true;
  };

  home.sessionVariables = rec {
    LC_ALL = "en_US.UTF-8";
    LANG = "en_US.UTF-8";
    # use 1password agent for ssh
    SSH_AUTH_SOCK = "\$HOME/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    WORKSPACE = "\$HOME/src";
  };

  home.packages = with pkgs; [
    # Some basics
    coreutils
    curl

    # GNU flavored basic tools
    gawk
    gnused
    gnugrep
    gnutar

    # Dev stuff
    # (agda.withPackages (p: [ p.standard-library ]))
    ctop                       # top for containers
    curlie                     # curl helper
    docker                     # container runtime
    dbeaver                    # db client
    # devenv                   # Fast, Declarative, Reproducible, and Composable Developer Environments using Nix
    inputs.dotenv.packages.${system}.default            # change env using a file for one off commands
    fd                         # fast find
    fira-code-nerdfont         # favorite dev font
    gnupg                      # gpg
    google-cloud-sdk           # gcloud
    jq                         # for handling json
    mosh                       # persistent ssh sessions
    nodejs_20                  # dependency for emacs Github Copilot (TODO: move)
    peco                       # choose options in cli scripts
    ripgrep                    # searching files fast
    unixtools.watch            # repeat commands and monitor their outputs

    pkgs-x86.caffeine          # prevent mac from sleeping
    cyberduck                  # sftp client
    discord                    # chat
    hexfiend                   # hex editor
    m-cli                      # useful macOS CLI commands
    # postman                  # api client
    reattach-to-user-namespace # tmux helper
    rectangle                  # window manager
    spotify                    # music
    slack                      # chat
    transmission               # torrent client
    vscode                     # code editor
    # vlc                      # media player
    zoom-us                    # video conferencing
    _1password                 # password manager
    pcasaretto.immersed-vr     # experiment with coding in VR

    qemu
  ];
}
