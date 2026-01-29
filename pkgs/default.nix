# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  cc-safety-net = pkgs.callPackage ./cc-safety-net {};
  nu_plugin_dns = pkgs.callPackage ./nu_plugin_dns {};
}
