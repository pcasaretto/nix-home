{ config, ... }:

let
  inherit (config.services.cyberspace) ports;
  sonarrExporterPort = ports.appExporters.sonarr;
in
{
  # Enable exportarr for Sonarr
  services.prometheus.exporters.exportarr-sonarr = {
    enable = true;
    port = sonarrExporterPort;
    url = "http://127.0.0.1:${toString ports.media.sonarr}";
    apiKeyFile = config.sops.secrets.sonarr-api-key.path;
  };

  # Ensure exporter starts after setup service completes
  systemd.services."prometheus-exportarr-sonarr-exporter" = {
    wants = [ "sonarr-setup.service" ];
    after = [ "sonarr-setup.service" ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.sonarr-exporter = {
    job_name = "sonarr";
    description = "Sonarr TV show manager metrics (series, episodes, downloads)";
    scrape_interval = "30s";
    targets = [ "localhost:${toString sonarrExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "exportarr-sonarr";
      service = "sonarr";
    };
    enabled = true;
    tags = [ "media" "automation" "tv" ];
  };
}
