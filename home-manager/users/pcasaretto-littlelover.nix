{pkgs, ...}: {
  imports = [
    ./pcasaretto.nix
  ];

  home.username = "pcasaretto";
  home.homeDirectory = "/Users/pcasaretto";

  # Littlelover-specific packages
  home.packages = with pkgs; [
    gnused
    unstable.gemini-cli
    vlc-bin
    perlPackages.AppMusicChordPro
  ];

  # Git: use vscode for diff/merge
  programs.git.settings = {
    diff.tool = "vscode";
    merge.tool = "vscode";
    difftool.vscode.cmd = "code --wait --diff $LOCAL $REMOTE";
    mergetool.vscode.cmd = "code --wait $MERGED";
  };
}
