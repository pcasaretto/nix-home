{ config, pkgs, lib, dotenv, devenv, ... }:
{
  home.stateVersion = "23.05";

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
    SSH_AUTH_SOCK = "\$HOME/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    WORKSPACE = "\$HOME/src";
  };

  home.packages = with pkgs; [
    # Some basics
    coreutils
    curl
    zsh

    # Dev stuff
    # (agda.withPackages (p: [ p.standard-library ]))
    babashka                   # clojure scripting
    coreutils                  # GNU coreutils
    ctop                       # top for containers
    curlie                     # curl helper
    dbeaver                    # db client
    devenv                     # Fast, Declarative, Reproducible, and Composable Developer Environments using Nix
    dotenv                     # change env using a file for one off commands
    fd                         # fast find
    fzf                        # fast fuzzy file finder
    gnupg
    google-cloud-sdk
    jq                         # for handling json
    kcat                       # cat for kafka
    mosh                       # persistent ssh sessions
    nodejs_20                  # dependency for emacs Github Copilot
    peco                       # choose options in cli scripts
    ripgrep                    # searching files fast
    rlwrap                     # wrap commands with a sane CLI
    unixtools.watch            # repeat commands and monitor their outputs
    # System admin stuff
    ncdu

    # Useful nix related tools
    # comma # run software from without installing it

  ] ++ lib.optionals stdenv.isDarwin [
    m-cli # useful macOS CLI commands
    reattach-to-user-namespace # tmux helper
  ];
}
