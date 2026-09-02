# Launch a separate Ghostty instance with the herdr keybindings
# (~/.config/ghostty-herdr/config). It runs beside the normal instance; each
# Ghostty process reads its keybinds at startup, so the rebinds stay scoped
# to that instance. To edit them: ghostty.nix, then `cmd+shift+,` inside the
# herdr instance to reload.

ghostty-herdr() {
  local bin app
  bin="$(command -v ghostty)" || {
    print -u2 "ghostty-herdr: ghostty not found on PATH"
    return 1
  }
  bin="${bin:A}"
  app="${bin:h:h}/Applications/Ghostty.app"
  if [[ ! -d "$app" ]]; then
    print -u2 "ghostty-herdr: no Ghostty.app next to $bin"
    return 1
  fi
  open -na "$app" --args --config-file="$HOME/.config/ghostty-herdr/config"
}
