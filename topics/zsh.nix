{ config, lib, pkgs, ... }:

{

  programs.zsh = {
    defaultKeymap = "viins";
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    shellAliases = {
      l = "ls -lAh";
      gst = "git status";
    };

    # initExtra = ''
    # typeset -u config_files
    # config_files=(/Users/pcasaretto/src/github.com/pcasaretto/dotfiles/zsh/*.zsh)

    # for file in ''${(M)config_files:#*/path.zsh}
    # do
    #   source $file
    # done

    # # use .localrc for SUPER SECRET CRAP that you don't
    # # want in your public, versioned repo.
    # if [[ -a ~/.localrc ]]
    # then
    #   source ~/.localrc
    # fi

    # # load everything but the path and completion files
    # for file in ''${''${config_files:#*/path.zsh}:#*/completion.zsh}
    # do
    #   source $file
    # done

    # unset config_files
    # '';

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
