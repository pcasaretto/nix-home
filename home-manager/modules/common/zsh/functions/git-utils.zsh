# Git utility functions

function _git_head_ref() {
  git symbolic-ref HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

function current_branch() {
  local ref=$(_git_head_ref) || return
  echo ${ref#refs/heads/}
}

function current_repository() {
  _git_head_ref >/dev/null || return
  echo $(git remote -v | cut -d':' -f 2)
}
