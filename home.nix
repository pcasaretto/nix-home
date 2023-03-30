{ config, pkgs, lib, dotenv, ... }:
{
  home.stateVersion = "22.05";

  # Direnv, load and unload environment variables depending on the current directory.
  # https://direnv.net
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Htop
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.htop.enable
  programs.htop.enable = true;
  programs.htop.settings.show_program_path = true;

  home.sessionVariables = {
    VISUAL = "code --wait";
    EDITOR = "${config.home.sessionVariables.VISUAL}";
    LC_ALL = "en_US.UTF-8";
    LANG   = "en_US.UTF-8";
  };

  home.packages = with pkgs; [
    # Some basics
    coreutils
    curl
    zsh

    # Dev stuff
    # (agda.withPackages (p: [ p.standard-library ]))
    google-cloud-sdk
    jq                         # for handling json
    ripgrep                    # searching files fast
    fzf                        # fast fuzzy file finder
    mosh                       # persistent ssh sessions
    ctop                       # top for containers
    kcat                       # cat for kafka
    gnupg
    babashka                   # clojure scripting
    peco                       # choose options in cli scripts
    unixtools.watch            # repeat commands and monitor their outputs
    rlwrap                     # wrap commands with a sane CLI
    curlie                     # curl helper
    dotenv                     # change env using a file for one off commands

    # System admin stuff
    ncdu

    # Useful nix related tools
    # comma # run software from without installing it

  ] ++ lib.optionals stdenv.isDarwin [
    m-cli # useful macOS CLI commands
    reattach-to-user-namespace # tmux helper
  ];
}
