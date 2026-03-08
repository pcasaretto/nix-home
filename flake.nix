{
  description = "Your new nix config";

  # the nixConfig here only affects the flake itself, not the system configuration!
  nixConfig = {
    trusted-users = ["pcasaretto" "paulo.casaretto"];

    extra-substituters = [
      # nix community's cache server
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      # nix community's cache server public key
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  inputs = {
    # Nixpkgs - separate inputs for darwin and nixos
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-nixos.url = "github:nixos/nixpkgs/nixos-25.11";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager"; # master branch for programs.claude-code
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    dotenv.url = "github:pcasaretto/dotenv";
    dotenv.inputs.nixpkgs.follows = "nixpkgs-darwin";

    flake-utils.url = "github:numtide/flake-utils";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-nixos";

    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    mac-app-util.url = "github:hraban/mac-app-util";
    # mac-app-util.inputs.nixpkgs.follows = "nixpkgs-darwin";
    # mac-app-util.inputs.treefmt-nix.nixpkgs.follows = "nixpkgs-darwin";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nix-doom-emacs-unstraightened.url = "github:marienz/nix-doom-emacs-unstraightened";
    nix-doom-emacs-unstraightened.inputs.nixpkgs.follows = "nixpkgs-unstable";

    try.url = "github:tobi/try";
    try.inputs.nixpkgs.follows = "nixpkgs-darwin";

    qmd.url = "github:tobi/qmd";
    qmd.inputs.nixpkgs.follows = "nixpkgs-unstable";
    qmd.inputs.flake-utils.follows = "flake-utils";

    tmux-git-worktree.url = "github:pcasaretto/tmux-git-worktree";
    tmux-git-worktree.inputs.nixpkgs.follows = "nixpkgs-unstable";

    tabline-wez = {
      url = "github:michaelbrusegard/tabline.wez";
      flake = false;
    };

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs-nixos";

    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    nixos-apple-silicon.inputs.nixpkgs.follows = "nixpkgs-nixos";

    spellbook.url = "git+ssh://git@github.com/pcasaretto/spellbook";
    spellbook.inputs.nixpkgs.follows = "nixpkgs-nixos";

    mysecrets = {
       url = "git+https://github.com/pcasaretto/nix-secrets.git?shallow=1";
       flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs-darwin,
    nixpkgs-nixos,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;

    # System categories
    darwinSystems = ["aarch64-darwin" "x86_64-darwin"];
    nixosSystems = ["aarch64-linux" "x86_64-linux"];
    allSystems = darwinSystems ++ nixosSystems;

    # Helper to get appropriate nixpkgs for a system
    nixpkgsFor = system:
      if builtins.elem system darwinSystems
      then nixpkgs-darwin
      else nixpkgs-nixos;

    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs-darwin.lib.genAttrs allSystems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system:
      import ./pkgs (nixpkgsFor system).legacyPackages.${system}
    );
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system:
      (nixpkgsFor system).legacyPackages.${system}.alejandra
    );

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;

    # Reusable home-manager modules consumed by downstream flakes
    # (e.g. a private Shopify overlay flake). Profiles under
    # home-manager/modules/profiles/ are deliberately NOT exposed here —
    # they are per-environment leaves, not reusable building blocks.
    homeManagerModules = {
      common = ./home-manager/modules/common;
      darwin = ./home-manager/modules/darwin;
      base-user = ./home-manager/users/pcasaretto.nix;
    };

    # Reusable nix-darwin modules consumed by downstream flakes.
    darwinModules = {
      core = ./hosts/common/core;
      darwin = ./hosts/common/darwin;
      mac-app-util = ./hosts/common/darwin/mac-app-util.nix;
    };

    # Standalone home-manager configurations
    # Available through 'home-manager switch --flake .#username'
    homeConfigurations = {
      # The "paulo.casaretto" (Shopify work) configuration has been moved
      # to a private overlay flake that consumes this one as an input.
      # See README "Consuming this flake from another flake".
      "pcasaretto@littlelover" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs-unstable.legacyPackages.aarch64-darwin;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home-manager/users/pcasaretto-littlelover.nix
        ];
      };
    };

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      cyberspace = nixpkgs-nixos.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          {
            # given the users in this list the right to specify additional substituters via:
            #    1. `nixConfig.substituters` in `flake.nix`
            nix.settings = {
              trusted-users = ["pcasaretto"];

              substituters = [
                "https://cache.nixos.org"
                "https://hyprland.cachix.org"
              ];
            };
          }
          ./hosts/common/core
          ./hosts/common/linux
          ./hosts/cyberspace
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
    };
  };
}
