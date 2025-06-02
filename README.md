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

## Resources

- [NixOS Wiki](https://nixos.wiki/wiki/Home)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/index.html)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS and Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [Misterio77 starter configs](https://github.com/Misterio77/nix-starter-configs)
- [hlissner dotfiles](https://github.com/hlissner/dotfiles)
