# Nix home

This started out as an experiment to move from my old dotfiles repo
to a functional configuration using Nix. It's still a work in progress.

## Installation


1. create a host config that matches your hostname under /hosts
2. add it under flake.nix

### Mac OS

3. bootstrap with `sudo nix run nix-darwin/nix-darwin-24.11#darwin-rebuild -- switch --flake`
4. `sudo darwin-rebuild switch --flake .`

### NixOS

TODO

## Consuming this flake from another flake

This flake exposes reusable building blocks so that a downstream flake (e.g. a
private Shopify overlay repo) can layer additional modules and users on top of
the base config without forking.

Work-specific configuration (paths under Shopify infrastructure, internal URLs,
hostnames, packages) should NOT be added to this public repo. Add it to the
private overlay flake instead.

Example consumer `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url          = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url     = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";
    darwin.url           = "github:lnl7/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-home-base.url = "github:pcasaretto/nix-home";
    nix-home-base.inputs.nixpkgs.follows          = "nixpkgs";
    nix-home-base.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    nix-home-base.inputs.home-manager.follows     = "home-manager";
    nix-home-base.inputs.darwin.follows           = "darwin";
  };

  outputs = { home-manager, nix-home-base, ... }@inputs: {
    homeConfigurations."yourname" = home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs-unstable.legacyPackages.aarch64-darwin;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        nix-home-base.homeManagerModules.base-user
        ./your-overlay.nix
      ];
    };
  };
}
```

Exposed outputs:

- `homeManagerModules.common`    — `home-manager/modules/common`
- `homeManagerModules.darwin`    — `home-manager/modules/darwin`
- `homeManagerModules.base-user` — `home-manager/users/pcasaretto.nix` (the
  shared base user; imports common + darwin)
- `darwinModules.core`           — `hosts/common/core`
- `darwinModules.darwin`         — `hosts/common/darwin`
- `darwinModules.mac-app-util`   — `hosts/common/darwin/mac-app-util.nix`
- `overlays.*`                   — `additions`, `modifications`,
  `unstable-packages`, `apple-silicon`
- `packages.<system>.*`          — custom packages from `pkgs/`

Profiles under `home-manager/modules/profiles/` are intentionally NOT exposed.
They are per-environment leaves and should be composed inside the consumer
flake's own tree.

## Resources

- [NixOS Wiki](https://nixos.wiki/wiki/Home)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/index.html)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS and Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [Misterio77 starter configs](https://github.com/Misterio77/nix-starter-configs)
- [hlissner dotfiles](https://github.com/hlissner/dotfiles)
