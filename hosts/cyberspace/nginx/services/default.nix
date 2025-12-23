{ ... }:

{
  imports = [
    ./system-info.nix
    ./ollama.nix
    ./open-webui.nix
    ./grafana.nix
    ./prometheus.nix
    ./transmission.nix
    # ./jellyfin.nix

    # Future service configurations will be imported here
    # Example:
    # ./nextcloud.nix
  ];
}
