{ config, ... }:

let
  prometheusConfig = config.services.prometheus;
in
{
  # Register in service registry
  services.cyberspace.registeredServices.prometheus = {
    name = "Prometheus";
    description = "Metrics collection and time-series database";
    path = "/prometheus";
    icon = "🔥";
    enabled = true;
    inherit (prometheusConfig) port;
    tags = [ "monitoring" "metrics" "database" ];
  };

  # Configure nginx reverse proxy
  services.nginx.virtualHosts."cyberspace" = {
    # Redirect /prometheus to /prometheus/ for proper routing
    locations."/prometheus" = {
      return = "301 /prometheus/";
    };

    locations."/prometheus/" = {
      proxyPass = "http://${prometheusConfig.listenAddress}:${toString prometheusConfig.port}/prometheus/";
    };
  };
}
