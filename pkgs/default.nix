# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  cc-safety-net = pkgs.callPackage ./cc-safety-net {};
  wezterm-bin = pkgs.callPackage ./wezterm-bin {};
  transmission-exporter = pkgs.callPackage ./transmission-exporter {};
  gamecontroller-udev-rules = pkgs.callPackage ./gamecontroller-udev-rules {};
  clawdbot = pkgs.callPackage ./clawdbot {};
  openai-tunnel-client = pkgs.callPackage ./openai-tunnel-client {};
}
