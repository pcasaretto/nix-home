# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: let
  upstreamStarship = pkgs.callPackage (pkgs.path + "/pkgs/by-name/st/starship/package.nix") {};
  customStarship = pkgs.callPackage ./starship {};
in {
  cc-safety-net = pkgs.callPackage ./cc-safety-net {};
  wezterm-bin = pkgs.callPackage ./wezterm-bin {};
  starship =
    if pkgs.lib.versionAtLeast upstreamStarship.version "1.25.0"
    then pkgs.lib.warn "nixpkgs starship is now ${upstreamStarship.version} — remove pkgs/starship/ custom package" upstreamStarship
    else customStarship;
}
