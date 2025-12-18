# littlelover (personal machine) user configuration
# Extends the base pcasaretto user module with machine-specific settings
{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [
    ../../../home-manager/users/pcasaretto.nix
    ./git.nix
  ];

  home.username = "pcasaretto";
  home.homeDirectory = "/Users/pcasaretto";

  # littlelover-specific packages
  home.packages = with pkgs; [
    gnused # GNU sed implementation
    unstable.spotify
    unstable.gemini-cli
    vlc-bin
  ];
}
