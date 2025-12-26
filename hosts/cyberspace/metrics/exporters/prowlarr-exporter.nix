{ config, ... }:

let
  ports = config.services.cyberspace.ports;
  prowlarrExporterPort = ports.appExporters.prowlarr;
in
{
  # Enable exportarr for Prowlarr
  services.prometheus.exporters.exportarr-prowlarr = {
    enable = true;
    port = prowlarrExporterPort;
    url = "http://127.0.0.1:${toString ports.media.prowlarr}";
    apiKeyFile = config.sops.secrets.prowlarr-api-key.path;
  };

  # Ensure exporter starts after Prowlarr service
  systemd.services."prometheus-exportarr-prowlarr-exporter" = {
    wants = [ "prowlarr.service" ];
    after = [ "prowlarr.service" ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.prowlarr-exporter = {
    job_name = "prowlarr";
    description = "Prowlarr indexer manager metrics (indexers, searches, grabs)";
    scrape_interval = "30s";
    targets = [ "localhost:${toString prowlarrExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "exportarr-prowlarr";
      service = "prowlarr";
    };
    enabled = true;
    tags = [ "media" "automation" "indexer" ];
  };
}
