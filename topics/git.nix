{ config, pkgs, ... }:
let
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
in
{
  home.shellAliases = {
    l    = "ls -lAh";
    gst  = "git status";
    gsw  = "git switch";
    gl   = "git pull --prune";
    gup  = "git pull --prune --rebase";
    gp   = "git push";
    gd   = "git diff";
    gc   = "git commit -v";
    gwc  = "git whatchanged -p --abbrev-commit --pretty=medium";
  };

  programs.git = {
    enable = true;

    aliases = {
      root = "rev-parse --show-toplevel";
      rb   = "for-each-ref --sort=-committerdate --count=10 --format='%(refname:short)' refs/heads/";
    };

    extraConfig = {
      credential.helper          = "osxkeychain";
      color.diff                 = "auto";
      color.status               = "auto";
      color.branch               = "auto";
      color.ui                   = "always";
      "color \"diff\""           = {
        meta       = "yellow bold";
        commit     = "green bold";
        frag       = "magenta bold";
        old        = "red bold";
        new        = "green bold";
        whitespace = "red reverse";
      };
      "color \"diff-highlight\"" = {
        oldNormal    = "red bold";
        oldHighlight = "red bold 52";
        newNormal    = "green bold";
        newHighlight = "green bold 22";
      };
      "color \"branch\""         = {
        current = "yellow reverse";
        local   = "yellow";
        remote  = "green";
      };
      "color \"status\""         = {
        added     = "yellow";
        changed   = "green";
        untracked = "cyan";
      };
      core.excludesfile           = toString gitignore;
      apply.whitespace            = "nowarn";
      merge.tool                  = "vimdiff";
      mergetool.prompt            = "true";
      diftool.prompt              = "true";
      mergetool.keepBackup        = "false";
      "mergetool \"vimdiff\"".cmd = "nvim -d $BASE $LOCAL $REMOTE $MERGED -c '$wincmd w' -c 'wincmd J'";
      help.autocorrect            = "1";
      push.default                = "simple";
      init.defaultBranch          = "main";
    };

    userName = "pcasaretto";
    userEmail = "pcasaretto@gmail.com";
  };

  # GitHub CLI
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.gh.enable
  # Aliases config in ./gh-aliases.nix
  programs.gh.enable = true;
  programs.gh.settings.git_protocol = "ssh";
}
