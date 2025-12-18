{
  config,
  pkgs,
  lib,
  ...
}: let
  gitignore = pkgs.writeText "gitignore" ''
    .DS_Store

    # Thumbnails
    ._*

    # Files that might appear on external disk
    .Spotlight-V100
    .Trashes

    .svn
    .tissues
    *~
    *.swp
    *.rbc
    .tm_properties
    .vscode

    #bundle install shims
    vendor/bundle

    #emacs shit
    *~
    .DS_Store
    *~
    *#
    .#*
  '';
in {
  home.shellAliases = {
    gst = "git status";
    gsw = "git switch";
    gup = "git pull";
    gp = "git push";
    gd = "git diff";
    gc = "git commit -v";
    gwc = "git whatchanged -p --abbrev-commit --pretty=medium";
  };

  programs.git = {
    enable = true;

    aliases = {
      root = "rev-parse --show-toplevel";
      rb = "for-each-ref --sort=-committerdate --count=10 --format='%(refname:short)' refs/heads/";
    };

    extraConfig = {
      color.diff = "auto";
      color.status = "auto";
      color.branch = "auto";
      color.ui = "always";
      "color \"diff\"" = {
        meta = "yellow bold";
        commit = "green bold";
        frag = "magenta bold";
        old = "red bold";
        new = "green bold";
        whitespace = "red reverse";
      };
      "color \"diff-highlight\"" = {
        oldNormal = "red bold";
        oldHighlight = "red bold 52";
        newNormal = "green bold";
        newHighlight = "green bold 22";
      };
      "color \"branch\"" = {
        current = "yellow reverse";
        local = "yellow";
        remote = "green";
      };
      "color \"status\"" = {
        added = "yellow";
        changed = "green";
        untracked = "cyan";
      };
      core.excludesfile = toString gitignore;
      apply.whitespace = "nowarn";
      mergetool.keepBackup = "false";
      help.autocorrect = "1";
      push.default = "simple";
      pull.rebase = "true";
      init.defaultBranch = "main";
      push.autoSetupRemote = "true";
    };

    userName = "Paulo Casaretto";
    userEmail = lib.mkDefault "pcasaretto@gmail.com";
  };

  programs.git.difftastic.enable = true;

  # GitHub CLI
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.gh.enable
  programs.gh.enable = true;
  programs.gh.settings.git_protocol = "ssh";
  programs.gh.package = pkgs.unstable.gh;
}
