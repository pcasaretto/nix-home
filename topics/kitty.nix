{ config, lib, pkgs, ... }:
{
  home.sessionVariables = {
    TERMINAL="kitty";
  };

programs.kitty = {
    enable = true;
    font = {
      name = "Fira Code";
      size = 18;
    };
    settings = {
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";
    };

    keybindings = {
      "cmd+shift+d"             = "send_text all \\x02\\x22";
      "cmd+d"                   = "send_text all \\x02\\x25";
      "cmd+w"                   = "send_text all \\x02\\x60";
      "cmd+h"                   = "send_text all \\x02\\x80";
      "cmd+j"                   = "send_text all \\x02\\xa0";
      "cmd+k"                   = "send_text all \\x02\\xb0";
      "cmd+l"                   = "send_text all \\x02\\xc0";
      "cmd+t"                   = "send_text all \\x02\\x63";
      "cmd+1"                   = "send_text all \\x02\\x31";
      "cmd+2"                   = "send_text all \\x02\\x32";
      "cmd+3"                   = "send_text all \\x02\\x33";
      "cmd+4"                   = "send_text all \\x02\\x34";
      "cmd+5"                   = "send_text all \\x02\\x35";
      "cmd+6"                   = "send_text all \\x02\\x36";
      "cmd+7"                   = "send_text all \\x02\\x37";
      "cmd+8"                   = "send_text all \\x02\\x38";
      "cmd+9"                   = "send_text all \\x02\\x39";
      "alt+up"                  = "send_text all \\x02\\x1b\\x5b\\x41";
      "alt+down"                = "send_text all \\x02\\x1b\\x5b\\x42";
      "alt+right"               = "send_text all \\x02\\x1b\\x5b\\x43";
      "alt+left"                = "send_text all \\x02\\x1b\\x5b\\x44";
      "cmd+shift+left_bracket"  = "send_text all \\x02\\x70";
      "cmd+shift+right_bracket" = "send_text all \\x02\\x6e";
      "cmd+shift+enter"         = "send_text all \\x02\\x7a";
    };
  };
}
