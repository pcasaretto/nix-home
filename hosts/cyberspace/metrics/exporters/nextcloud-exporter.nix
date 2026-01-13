{ config, ... }:

let
  inherit (config.services.cyberspace) domain;
  inherit (config.services.cyberspace) ports;
in
{
  # Enable Nextcloud exporter
  services.prometheus.exporters.nextcloud = {
    enable = true;
    port = ports.appExporters.nextcloud;
    url = "https://nextcloud.${domain}";
    username = "admin";
    passwordFile = config.sops.secrets.nextcloud-exporter-password.path;
    extraFlags = [
      "--enable-info-apps"
      "--enable-info-update"
    ];
  };

  # Ensure exporter starts after Nextcloud setup
  systemd.services."prometheus-nextcloud-exporter" = {
    requires = [ "nextcloud-setup.service" ];
    after = [ "nextcloud-setup.service" ];
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.nextcloud-exporter = {
    job_name = "nextcloud";
    description = "Nextcloud server metrics (users, storage, apps)";
    scrape_interval = "60s";
    targets = [ "localhost:${toString ports.appExporters.nextcloud}" ];
    labels = {
      instance = "cyberspace";
      exporter = "nextcloud";
      service = "nextcloud";
    };
    enabled = true;
    tags = [ "productivity" "storage" ];
  };
}
