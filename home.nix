{ config, pkgs, lib, ... }:
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
    VISUAL = "emacs -nw";
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
    jq
    ripgrep
    fzf
    mosh
    reattach-to-user-namespace
    ctop
    kcat
    gnupg
    babashka
    peco
    unixtools.watch
    rlwrap

    # System admin stuff
    ncdu

    # Useful nix related tools
    # comma # run software from without installing it

  ] ++ lib.optionals stdenv.isDarwin [
    m-cli # useful macOS CLI commands
  ];
}
