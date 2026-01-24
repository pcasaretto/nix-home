{ config, ... }:

let
  inherit (config.services.cyberspace) domain ports;
in
{
  # Register in service registry
  services.cyberspace.registeredServices.loki = {
    name = "Loki";
    description = "Log aggregation system for collecting and querying logs";
    url = "https://loki.${domain}";
    icon = "📋";
    enabled = true;
    port = ports.monitoring.loki;
    tags = [ "monitoring" "logs" "observability" ];
  };

  # Configure Caddy reverse proxy
  services.caddy.virtualHosts."loki.${domain}" = {
    extraConfig = ''
      ${config.services.cyberspace.tlsConfig}
      reverse_proxy http://127.0.0.1:${toString ports.monitoring.loki}
    '';
  };
}
