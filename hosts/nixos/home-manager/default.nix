{
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../../home-manager/common
  ];

  home.shellAliases = {
    kubectl-switch-context = "kubectl config get-contexts -o name | peco | xargs kubectl config use-context";
  };

  home.packages = [
    pkgs.neovim
    pkgs.kubectl
    pkgs.kubernetes-helm
    (pkgs.google-cloud-sdk.withExtraComponents [pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin])
  ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "23.11";
}
