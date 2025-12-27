{ ... }:

{
  imports = [
    ./system-info.nix
    ./ollama.nix
    ./open-webui.nix
    ./grafana.nix
    ./prometheus.nix
    ./transmission.nix
    ./pihole.nix
    ./jellyfin.nix

    # *arr Media Management Stack
    ./sonarr.nix
    ./radarr.nix
    ./prowlarr.nix

    # Future service configurations will be imported here
    # Example:
    # ./nextcloud.nix
  ];
}
