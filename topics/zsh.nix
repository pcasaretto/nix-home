{ config, lib, pkgs, ... }:

{

  programs.zsh = {
    defaultKeymap = "viins";
    enable = true;
    enableCompletion = true;
    shellAliases = {
      l = "ls -lAh";
      gst = "git status";
    };

    initExtra = ''
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
        MODE_TEXT="''${''${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/}"
        RPS1='$MODE_TEXT $(git_custom_status) $EPS1'
        zle reset-prompt
    }

    zle -N zle-line-init
    zle -N zle-keymap-select

    precmd() { print -rP '%F{cyan}%~%f '}
    PROMPT="%(?.%{$fg[green]%}.%{$fg[red]%})%Bλ%b "
    '';

    plugins = with pkgs; [
      {
        name = "zsh-syntax-highlighting";
        src = fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.6.0";
          sha256 = "0zmq66dzasmr5pwribyh4kbkk23jxbpdw4rjxx0i7dx8jjp2lzl4";
        };
        file = "zsh-syntax-highlighting.zsh";
      }
      {
        name = "zsh-autopair";
        src = fetchFromGitHub {
          owner = "hlissner";
          repo = "zsh-autopair";
          rev = "34a8bca0c18fcf3ab1561caef9790abffc1d3d49";
          sha256 = "1h0vm2dgrmb8i2pvsgis3lshc5b0ad846836m62y8h3rdb3zmpy1";
        };
        file = "autopair.zsh";
      }
    ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

}
