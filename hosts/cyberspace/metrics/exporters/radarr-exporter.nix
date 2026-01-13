{ config, ... }:

let
  inherit (config.services.cyberspace) ports;
  radarrExporterPort = ports.appExporters.radarr;
in
{
  # Enable exportarr for Radarr
  services.prometheus.exporters.exportarr-radarr = {
    enable = true;
    port = radarrExporterPort;
    url = "http://127.0.0.1:${toString ports.media.radarr}";
    apiKeyFile = config.sops.secrets.radarr-api-key.path;
  };

  # Ensure exporter starts after setup service completes
  systemd.services."prometheus-exportarr-radarr-exporter" = {
    wants = [ "radarr-setup.service" ];
    after = [ "radarr-setup.service" ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.radarr-exporter = {
    job_name = "radarr";
    description = "Radarr movie manager metrics (movies, downloads, quality)";
    scrape_interval = "30s";
    targets = [ "localhost:${toString radarrExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "exportarr-radarr";
      service = "radarr";
    };
    enabled = true;
    tags = [ "media" "automation" "movies" ];
  };
}
