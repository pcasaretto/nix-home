{ ... }:

{
  imports = [
    ./dashboard.nix
    ./grafana.nix
    ./prometheus.nix
    ./ollama.nix
    ./open-webui.nix
    ./jellyfin.nix
    ./sonarr.nix
    ./radarr.nix
    ./prowlarr.nix
    ./transmission.nix
    ./pihole.nix
    ./ntfy.nix
    ./nextcloud.nix
    ./home-assistant.nix
  ];
}
