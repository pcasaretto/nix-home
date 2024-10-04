# This file (and the global directory) holds config that i use on all hosts
{ inputs, outputs, pkgs, ... }: {
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin

    inputs.nix-index-database.hmModules.nix-index

    ./git.nix
    ./tmux.nix
    ./xdg.nix
    ./zsh.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

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

  programs.nix-index-database.comma.enable = true;
  programs.nix-index.enable = true;

  home.shellAliases = {
    l    = "ls -lAh";
  };

  home.sessionVariables = {
    LC_ALL = "en_US.UTF-8";
    LANG = "en_US.UTF-8";
  };

  catppuccin.flavor = "frappe";

  home.packages = with pkgs; [
    # Some basics
    # coreutils
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
    fd                         # fast find
    fira-code-nerdfont         # favorite dev font
    gnupg                      # gpg
    jq                         # for handling json
    mosh                       # persistent ssh sessions
    peco                       # choose options in cli scripts
    ripgrep                    # searching files fast
    unixtools.watch            # repeat commands and monitor their outputs
    unstable.devenv            # dev environments made easy
    tree                       # directory tree viewer
  ];
}
