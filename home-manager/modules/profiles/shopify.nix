# Shopify work environment profile
# Contains dev tooling, shell integrations, and work-specific settings
{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./shopify/claude-code.nix
    ./shopify/starship.nix
  ];

  # Shopify dev environment initialization
  programs.zsh.initContent = lib.mkAfter ''
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

    # Override fzf to always use home-manager's version, avoiding PATH conflicts with tectonix
    fzf() { ${pkgs.fzf}/bin/fzf "$@" }
  '';

  # Shopify git email
  programs.git.settings.user.email = lib.mkForce "paulo.casaretto@shopify.com";
}
