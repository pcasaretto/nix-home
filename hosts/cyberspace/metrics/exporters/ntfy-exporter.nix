{ config, ... }:

let
  inherit (config.services.cyberspace) ports;
  ntfyMetricsPort = ports.appExporters.ntfy;
in
{
  # ntfy has built-in Prometheus metrics via /metrics endpoint
  # The metrics endpoint is configured in the main ntfy service configuration
  # This file just registers it in the metrics registry for Prometheus scraping

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.ntfy-exporter = {
    job_name = "ntfy";
    description = "ntfy notification service metrics (messages, subscribers, topics, visitors)";
    scrape_interval = "30s";
    targets = [ "localhost:${toString ntfyMetricsPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "ntfy";
      service = "ntfy";
    };
    enabled = true;
    tags = [ "notification" "messaging" "monitoring" ];
  };
}
