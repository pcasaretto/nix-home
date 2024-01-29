{
  description = "pcasaretto's darwin system";

  inputs = {

    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-23.11-darwin";
    nixpkgs-unstable.url = github:NixOS/nixpkgs/nixpkgs-unstable;

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    dotenvFlake.url = "github:pcasaretto/dotenv";

    devenv.url = "github:cachix/devenv/latest";
  };

  outputs = {
    self,
    darwin,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    dotenvFlake,
    devenv,
    ...
  }@inputs:
  let

  inherit (darwin.lib) darwinSystem;
  inherit (inputs.nixpkgs-unstable.lib) attrValues makeOverridable optionalAttrs singleton;

  # Configuration for `nixpkgs`
  nixpkgsConfig = {
    config = { allowUnfree = true; };
    overlays = attrValues self.overlays;
  };

  specialArgs = {system}:{
    dotenv = dotenvFlake.packages.${system}.default;
    devenv = devenv.packages.${system}.devenv;
  };

  in
  {
      darwinConfigurations.overdose = darwin.lib.darwinSystem rec {
        system = "aarch64-darwin";
        modules = [
          # Main `nix-darwin` config
          ./hosts/overdose
          # `home-manager` module
          home-manager.darwinModules.home-manager
          {
            nixpkgs = nixpkgsConfig;
            # `home-manager` config
            home-manager.extraSpecialArgs = specialArgs { inherit system; };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };

      overlays = {
        # Overlay useful on Macs with Apple Silicon
        apple-silicon = final: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          # Add access to x86 packages system is running Apple Silicon
          pkgs-x86 = import inputs.nixpkgs-unstable {
            system = "x86_64-darwin";
            inherit (nixpkgsConfig) config;
          };
        };
      };
    };
}
