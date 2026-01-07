{ config, ... }:

let
  domain = config.services.cyberspace.domain;
  prometheusConfig = config.services.prometheus;
in
{
  # Register in service registry
  services.cyberspace.registeredServices.prometheus = {
    name = "Prometheus";
    description = "Metrics collection and time-series database";
    url = "https://prometheus.${domain}";
    icon = "🔥";
    enabled = true;
    port = prometheusConfig.port;
    tags = [ "monitoring" "metrics" "database" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."prometheus.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://${prometheusConfig.listenAddress}:${toString prometheusConfig.port}
    '';
  };
}
