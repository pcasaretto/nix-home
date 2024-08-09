{ config, pkgs, ... }:
{
  programs.git = {
      diff.tool                   = "vscode";
      "difftool \"vscode\"".cmd   = "code --wait --diff $LOCAL $REMOTE";
      merge.tool                  = "vscode";
      "mergetool \"vscode\"".cmd  = "code --wait $MERGED";
  };
}
