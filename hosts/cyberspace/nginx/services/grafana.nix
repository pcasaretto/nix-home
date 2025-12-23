{ config, pkgs, ... }:

let
  grafanaConfig = config.services.grafana.settings.server;
  grafanaPort = grafanaConfig.http_port;
in
{
  # Register in service registry
  services.cyberspace.registeredServices.grafana = {
    name = "Grafana";
    description = "Metrics visualization and dashboards";
    path = "/grafana";
    icon = "📊";
    enabled = true;
    port = grafanaPort;
    tags = [ "monitoring" "metrics" "visualization" ];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    locations."/grafana" = {
      extraConfig = ''
        return 301 /grafana/;
      '';
    };
    locations."/grafana/" = {
      proxyPass = "http://${grafanaConfig.http_addr}:${toString grafanaPort}/grafana/";
    };
  };
}
