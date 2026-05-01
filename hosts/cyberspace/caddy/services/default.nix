{ ... }:

{
  imports = [
    ./dashboard.nix
    ./grafana.nix
    ./prometheus.nix
    ./loki.nix
    ./ollama.nix
    ./open-webui.nix
    ./jellyfin.nix
    ./sonarr.nix
    ./radarr.nix
    ./prowlarr.nix
    ./transmission.nix
    ./pihole.nix
    ./home-assistant.nix
    ./spellbook.nix
    ./planarally.nix
  ];
}
