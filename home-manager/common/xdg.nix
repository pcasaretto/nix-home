# copied from https://github.com/hlissner/dotfiles/blob/089f1a9da9018df9e5fc200c2d7bef70f4546026/modules/xdg.nix
#
# xdg.nix
#
# Set up and enforce XDG compliance. Other modules will take care of their own,
# but this takes care of the general cases.

{ config, home-manager, ... }:
{
  ### A tidy $HOME is a tidy mind
  config.xdg.enable = true;
}
