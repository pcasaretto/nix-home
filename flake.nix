{
  description = "Your new nix config";

  # the nixConfig here only affects the flake itself, not the system configuration!
  nixConfig = {
    trusted-users = ["pcasaretto" "paulo.casaretto"];

    extra-substituters = [
      # nix community's cache server
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      # nix community's cache server public key
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager"; # master branch for programs.claude-code
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    dotenv.url = "github:pcasaretto/dotenv";
    dotenv.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";

    mac-app-util.url = "github:hraban/mac-app-util";
    # mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    # mac-app-util.inputs.treefmt-nix.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nix-doom-emacs-unstraightened.url = "github:marienz/nix-doom-emacs-unstraightened";
    nix-doom-emacs-unstraightened.inputs.nixpkgs.follows = "nixpkgs";

    try.url = "github:tobi/try";
    try.inputs.nixpkgs.follows = "nixpkgs";

    qmd.url = "github:tobi/qmd";
    qmd.inputs.nixpkgs.follows = "nixpkgs";
    qmd.inputs.flake-utils.follows = "flake-utils";

    tmux-git-worktree.url = "github:pcasaretto/tmux-git-worktree";
    tmux-git-worktree.inputs.nixpkgs.follows = "nixpkgs";

    tabline-wez = {
      url = "github:michaelbrusegard/tabline.wez";
      flake = false;
    };

    # mysecrets = {
    #    url = "git+ssh://git@github.com/pcasaretto/nix-secrets.git?shallow=1";
    #    flake = false;
    # };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    # homeManagerModules = import ./modules/home-manager;

    # Standalone home-manager configurations
    # Available through 'home-manager switch --flake .#username'
    homeConfigurations = {
      "paulo.casaretto" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home-manager/users/paulo.casaretto.nix
        ];
      };

      "pcasaretto@littlelover" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home-manager/users/pcasaretto-littlelover.nix
        ];
      };
    };

    # nix-darwin configurations
    # Available through 'darwin-rebuild switch --flake .#hostname'
    darwinConfigurations = {
      littlelover = inputs.darwin.lib.darwinSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          {
            # given the users in this list the right to specify additional substituters via:
            #    1. `nixConfig.substituters` in `flake.nix`
            nix.settings = {
              trusted-users = ["pcasaretto"];

              substituters = [
                "https://cache.nixos.org"
                "https://nix-community.cachix.org"
              ];

              trusted-public-keys = [
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
            };
          }
          ./hosts/common/core
          ./hosts/common/darwin
          ./hosts/common/darwin/mac-app-util.nix
          ./hosts/littlelover
        ];
      };

      overdose = inputs.darwin.lib.darwinSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          {
            # given the users in this list the right to specify additional substituters via:
            #    1. `nixConfig.substituters` in `flake.nix`
            nix.settings = {
              trusted-users = ["pcasaretto"];

              substituters = [
                "https://cache.nixos.org"
                "https://nix-community.cachix.org"
              ];

              trusted-public-keys = [
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
            };
          }
          ./hosts/common/core
          ./hosts/common/darwin
          ./hosts/common/darwin/mac-app-util.nix
          ./hosts/overdose
        ];
      };
    };
  };
}
