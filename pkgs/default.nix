# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  nu_plugin_dns = pkgs.callPackage ./nu_plugin_dns {};
  transmission-exporter = pkgs.callPackage ./transmission-exporter {};
  gamecontroller-udev-rules = pkgs.callPackage ./gamecontroller-udev-rules {};
}
