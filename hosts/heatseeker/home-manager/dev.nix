{ config, pkgs, ... }:
{
  programs.zsh.initContent = ''
  [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh
  [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
  [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
  # Added by //areas/tools/world-up
  [[ -x ~/world/.tectonix/init ]] && eval "$(~/world/.tectonix/init zsh)"
  '';
}
