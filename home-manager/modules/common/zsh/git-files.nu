# Git files grouped by status for fzf picker (called from zsh Ctrl+G)
# Output format: STATUS<tab>FILENAME (tab-delimited so fzf can search only filename)
# Colors: green=staged, yellow=modified, cyan=untracked, dim=tracked
# Uses git status --porcelain for speed in large repos

def main [] {
  let is_git = (do { git rev-parse --is-inside-work-tree } | complete | get exit_code) == 0
  if not $is_git {
    fd --type f --strip-cwd-prefix | lines | each { |f| $"(ansi white)file\t($f)(ansi reset)" }
    return
  }

  # Get path prefix to strip (path from git root to cwd)
  let git_root = (git rev-parse --show-toplevel | str trim)
  let cwd = (pwd)
  let prefix = if $cwd == $git_root { "" } else { ($cwd | str replace $"($git_root)/" "") + "/" }

  # Use git status --porcelain . for current dir only
  let status_lines = (do { git status --porcelain . } | complete | get stdout | lines)

  mut staged = []
  mut modified = []
  mut untracked = []

  for line in $status_lines {
    let index_status = ($line | str substring 0..0)
    let worktree_status = ($line | str substring 1..1)
    let raw_file = ($line | str substring 3..)
    # Strip prefix to make path relative to cwd
    let file = if ($prefix | is-empty) { $raw_file } else { $raw_file | str replace $prefix "" }

    # Staged: something in index (not ? or !)
    if $index_status in ["A", "M", "D", "R", "C"] {
      $staged = ($staged | append $file)
    }
    # Modified in worktree
    if $worktree_status == "M" {
      $modified = ($modified | append $file)
    }
    # Untracked
    if $index_status == "?" {
      $untracked = ($untracked | append $file)
    }
  }

  mut output = []

  # Staged (green)
  for f in $staged {
    $output = ($output | append $"(ansi green_bold)staged\t(ansi green)($f)(ansi reset)")
  }

  # Modified (yellow)
  for f in $modified {
    $output = ($output | append $"(ansi yellow_bold)modified\t(ansi yellow)($f)(ansi reset)")
  }

  # If no dirty files, fall back to fd for tracked files (fast, respects .gitignore)
  if ($output | length) == 0 {
    if ($untracked | length) > 0 {
      # Show untracked if that's all we have
      for f in $untracked {
        $output = ($output | append $"(ansi cyan_bold)untracked\t(ansi cyan)($f)(ansi reset)")
      }
    } else {
      # No dirty files at all - use fd (respects gitignore, fast)
      let tracked = (do { fd --type f --strip-cwd-prefix } | complete | get stdout | lines | first 500)
      for f in $tracked {
        $output = ($output | append $"(ansi dark_gray)tracked\t(ansi white)($f)(ansi reset)")
      }
    }
  }

  $output | str join "\n"
}
