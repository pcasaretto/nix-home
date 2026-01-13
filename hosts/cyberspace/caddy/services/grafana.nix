{ config, ... }:

let
  inherit (config.services.cyberspace) domain;
  grafanaConfig = config.services.grafana.settings.server;
  grafanaPort = grafanaConfig.http_port;
in
{
  # Register in service registry
  services.cyberspace.registeredServices.grafana = {
    name = "Grafana";
    description = "Metrics visualization and dashboards";
    url = "https://grafana.${domain}";
    icon = "📊";
    enabled = true;
    port = grafanaPort;
    tags = [ "monitoring" "metrics" "visualization" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."grafana.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://${grafanaConfig.http_addr}:${toString grafanaPort}
    '';
  };
}
