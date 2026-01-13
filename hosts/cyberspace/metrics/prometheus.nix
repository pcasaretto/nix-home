{ config, lib, ... }:

let
  inherit (config.services.cyberspace) ports;
  # Get all registered metrics
  inherit (config.services.cyberspace.metrics) registeredMetrics;

  # Convert metrics registry to Prometheus scrape configs
  # Only include enabled metrics
  metricsToScrapeConfigs = lib.mapAttrsToList
    (name: metricsConfig: {
      inherit (metricsConfig) job_name;
      inherit (metricsConfig) scrape_interval;
      static_configs = [{
        inherit (metricsConfig) targets;
        labels = metricsConfig.labels // {
          # Add source identifier
          metrics_source = name;
        };
      }];
    })
    (lib.filterAttrs (_name: m: m.enabled) registeredMetrics);
in
{
  services.prometheus = {
    enable = true;

    # Listen on localhost only - nginx will proxy if needed
    listenAddress = "127.0.0.1";
    port = ports.monitoring.prometheus;

    # No longer needed with subdomain routing:
    # webExternalUrl = "http://cyberspace/prometheus/";
    # extraFlags = [ "--web.route-prefix=/prometheus" ];

    # Global configuration
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
      # External labels for federation/alerting
      external_labels = {
        host = "cyberspace";
        environment = "homelab";
      };
    };

    # Retention configuration
    retentionTime = "30d";  # Keep 30 days of metrics

    # Auto-generated scrape configs from registry
    scrapeConfigs = metricsToScrapeConfigs ++ [
      # Prometheus self-monitoring (always included)
      {
        job_name = "prometheus";
        # Updated: no longer has /prometheus prefix
        metrics_path = "/metrics";
        static_configs = [{
          targets = [ "localhost:9090" ];
          labels = {
            instance = "cyberspace-prometheus";
          };
        }];
      }
    ];

    # Recording rules and alerts can be added here
    # rules = [ ... ];
    # alertmanagers = [ ... ];
  };

  # Ensure Prometheus starts after network
  systemd.services.prometheus = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
