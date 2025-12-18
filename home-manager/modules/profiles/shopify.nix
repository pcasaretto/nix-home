# Shopify work environment profile
# Contains dev tooling, shell integrations, and work-specific settings
{
  config,
  pkgs,
  lib,
  ...
}: {
  # World aliases
  programs.zsh.shellAliases = {
    ls = "wls";
    cd = "wcd";
  };

  # Shopify dev environment initialization
  programs.zsh.initContent = ''
    # Shopify dev.sh
    [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

    # Ruby version management
    [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }

    # Homebrew
    [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

    # World/Tectonix
    [[ -x ~/world/.tectonix/init ]] && eval "$(~/world/.tectonix/init zsh)"

    # Tec agent
    [[ -x ~/.local/state/tec/profiles/base/current/global/init ]] && eval "$(~/.local/state/tec/profiles/base/current/global/init zsh)"

    eval "$(wcd --init zsh)"
  '';

  # Shopify git email
  programs.git.userEmail = lib.mkForce "paulo.casaretto@shopify.com";
}
