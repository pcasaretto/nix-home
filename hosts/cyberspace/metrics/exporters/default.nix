{ ... }:

{
  imports = [
    ./node-exporter.nix
    # Removed: nginx-exporter.nix - Caddy provides built-in metrics
    ./sonarr-exporter.nix
    ./radarr-exporter.nix
    ./prowlarr-exporter.nix
    ./transmission-exporter.nix
    ./ntfy-exporter.nix
    ./nextcloud-exporter.nix
    ./home-assistant-exporter.nix
  ];
}
