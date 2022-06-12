# ls colors
autoload colors; colors;
export LSCOLORS="Gxfxcxdxbxegedabagacad"

# Enable ls colors
if [ "$DISABLE_LS_COLORS" != "true" ]
then
  # Find the option for using colors in ls, depending on the version: Linux or BSD
  if [[ "$(uname -s)" == "NetBSD" ]]; then
    # On NetBSD, test if "gls" (GNU ls) is installed (this one supports colors); 
    # otherwise, leave ls as is, because NetBSD's ls doesn't support -G
    gls --color -d . &>/dev/null 2>&1 && alias ls='gls --color=tty'
  else
    ls --color -d . &>/dev/null 2>&1 && alias ls='ls --color=tty' || alias ls='ls -G'
  fi
fi

#setopt no_beep
setopt auto_cd
setopt multios
setopt cdablevarS

if [[ x$WINDOW != x ]]
then
    SCREEN_NO="%B$WINDOW%b "
else
    SCREEN_NO=""
fi

# # Apply theming defaults
# PS1="%n@%m:%~%# "

# # git theming default: Variables for theming the git info prompt
# ZSH_THEME_GIT_PROMPT_PREFIX="git:("         # Prefix at the very beginning of the prompt, before the branch name
# ZSH_THEME_GIT_PROMPT_SUFFIX=")"             # At the very end of the prompt
# ZSH_THEME_GIT_PROMPT_DIRTY="*"              # Text to display if the branch is dirty
# ZSH_THEME_GIT_PROMPT_CLEAN=""               # Text to display if the branch is clean

# # Setup the prompt with pretty colors
setopt prompt_subst

ZSH_THEME_GIT_PROMPT_PREFIX="%{$reset_color%}%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="]%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

#Customized git status, oh-my-zsh currently does not allow render dirty status before branch
git_custom_status() {
  # local cb=FIXME
  # if [ -n "$cb" ]; then
  #   echo "$(parse_git_dirty)$ZSH_THEME_GIT_PROMPT_PREFIX$(current_branch)$ZSH_THEME_GIT_PROMPT_SUFFIX"
  # fi
  echo "FIXME"
}

RPS1='$(git_custom_status) $EPS1'

function zle-line-init zle-keymap-select {
    VIM_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]% %{$reset_color%}"
    MODE_TEXT="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/}"
    RPS1='$MODE_TEXT $(git_custom_status) $EPS1'
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select

precmd() { print -rP '%F{cyan}%~%f '}
PROMPT="%(?.%{$fg[green]%}.%{$fg[red]%})%Bλ%b "
