# User configuration for paulo.casaretto (Shopify work machine)
# Extends the base pcasaretto user module with Shopify-specific settings
# Activate with: home-manager switch --flake .#paulo.casaretto
{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [
    ./pcasaretto.nix # Base config
    ../modules/profiles/shopify.nix # Shopify additions
  ];

  # Work identity
  home.username = "paulo.casaretto";
  home.homeDirectory = "/Users/paulo.casaretto";

  # Work-specific packages
  home.packages = with pkgs; [
    uv # python package manager
  ];
}
