{
  config,
  lib,
  pkgs,
  ...
}: let
  customZshStuff =
    builtins.concatStringsSep "\n"
    (
      map builtins.readFile [
        ./zsh/functions/current_branch.zsh
        ./zsh/functions/current_repository.zsh
        ./zsh/functions/e.zsh
        ./zsh/functions/git_functions.zsh
        ./zsh/correction.zsh
        ./zsh/completion.zsh
        ./zsh/history.zsh
        ./zsh/vi-mode.zsh
      ]
    );
in {
  programs.zsh = {
    defaultKeymap = "viins";
    enable = true;
    enableCompletion = true;
    shellAliases = {
      l = "ls -lAh";
      gst = "git status";
    };

    initExtra = customZshStuff;

    plugins = with pkgs; [
      {
        name = "zsh-syntax-highlighting";
        src = fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.8.0";
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

  programs.fzf = rec {
    enable = true;
    defaultCommand = "fd --type f --strip-cwd-prefix";
    fileWidgetCommand = defaultCommand;
    enableZshIntegration = true;
  };
}
