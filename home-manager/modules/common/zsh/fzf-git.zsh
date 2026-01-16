# Ctrl+G: Git-aware file picker using nushell + fzf
# Output is tab-delimited: STATUS<tab>FILENAME
# --nth=2 searches only filename, --delimiter='\t' splits on tab
fzf-git-file-widget() {
  local selected
  selected=$(nu "$FZF_GIT_FILES_SCRIPT" | fzf --ansi \
    --header="Git Files (Ctrl+G)" \
    --delimiter=$'\t' \
    --nth=2 \
    --preview 'f=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -f2); [[ -f "$f" ]] && bat --style=numbers --color=always "$f" 2>/dev/null || echo "Not a file: $f"' \
    --bind 'ctrl-/:toggle-preview' \
    | sed 's/\x1b\[[0-9;]*m//g' | cut -f2)

  if [[ -n "$selected" ]]; then
    LBUFFER="${LBUFFER}${selected}"
  fi
  zle reset-prompt
}

zle -N fzf-git-file-widget
bindkey '^G' fzf-git-file-widget
