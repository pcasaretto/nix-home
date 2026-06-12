# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  cc-safety-net = pkgs.callPackage ./cc-safety-net {};
  knowledge-publisher = pkgs.callPackage ./knowledge-publisher {};
  wezterm-bin = pkgs.callPackage ./wezterm-bin {};
}
