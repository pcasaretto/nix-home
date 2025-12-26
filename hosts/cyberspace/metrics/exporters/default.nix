{ ... }:

{
  imports = [
    ./node-exporter.nix
    ./nginx-exporter.nix
    ./sonarr-exporter.nix
    ./radarr-exporter.nix
    ./prowlarr-exporter.nix
    ./transmission-exporter.nix
  ];
}
