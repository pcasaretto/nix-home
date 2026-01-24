{ ... }:

{
  imports = [
    ./metrics-registry.nix
    ./prometheus.nix
    ./grafana.nix
    ./loki.nix
    ./alloy.nix
    ./exporters
  ];

  # Optional: Open firewall for metrics on Tailscale interface
  # This allows direct access to Prometheus/Grafana without nginx
  # Uncomment if you want direct access:
  # networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
  #   config.services.prometheus.port
  #   config.services.grafana.settings.server.http_port
  # ];
}
