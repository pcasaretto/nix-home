{ config, pkgs, ... }:
{
  programs.zsh.initExtra = ''
  [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh
  [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
  [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
  '';
}