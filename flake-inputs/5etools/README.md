# 5etools 2014 Nix package

This flake packages the static 5etools 2014 site from [`5etools-mirror-3/5etools-2014-src`](https://github.com/5etools-mirror-3/5etools-2014-src) so it can be served by a homelab web server. The Nix build runs the upstream production build, including generated CSS/pages/search data and `sw.js`/`sw-injector.js`.

## Build

```sh
nix build .#
```

The static site is produced at `result/`.

## NixOS usage sketch

Add this repository as a flake input, then serve `inputs.5etools.packages.${pkgs.system}.default` as a static root with nginx/caddy/etc.

Example nginx root expression:

```nix
root = inputs.5etools.packages.${pkgs.system}.default;
```

Currently pinned upstream revision: `da55a2820fb547651d9e2833262fb73ce9ce969e` (`1.217.0`). The package also marks the site as deployed and serves image assets locally from `/img/`, backed by the packaged `5etools-mirror-3/5etools-img` asset tree.
