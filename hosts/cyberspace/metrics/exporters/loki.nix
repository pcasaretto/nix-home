{ config, ... }:

let
  ports = config.services.cyberspace.ports;
in
{
  # Register Loki's native Prometheus metrics endpoint
  # Loki exposes metrics at /metrics on its HTTP port
  services.cyberspace.metrics.registeredMetrics.loki = {
    enabled = true;
    job_name = "loki";
    description = "Loki log aggregation system metrics";
    scrape_interval = "15s";
    targets = [
      "127.0.0.1:${toString ports.monitoring.loki}"
    ];
    labels = {
      instance = "cyberspace";
      service = "loki";
      component = "logging";
    };
    tags = [ "monitoring" "logs" "observability" ];
  };
}
