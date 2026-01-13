{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) ports;
  transmissionExporterPort = ports.appExporters.transmission;
in
{
  # Define transmission-exporter service manually (not in nixpkgs exporters)
  systemd.services.prometheus-transmission-exporter = {
    description = "Prometheus Transmission Exporter";
    wantedBy = [ "multi-user.target" ];
    wants = [ "transmission.service" ];
    after = [ "transmission.service" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      ExecStart = "${pkgs.transmission-exporter}/bin/transmission-exporter --webaddr=127.0.0.1:${toString transmissionExporterPort} --transmissionaddr=http://127.0.0.1:${toString ports.apps.transmission}";
      Restart = "on-failure";

      # Hardening
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [];
    };
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.transmission-exporter = {
    job_name = "transmission";
    description = "Transmission BitTorrent client metrics (torrents, speeds, ratios)";
    scrape_interval = "15s";
    targets = [ "localhost:${toString transmissionExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "transmission";
      service = "transmission";
    };
    enabled = true;
    tags = [ "download" "torrent" "media" ];
  };
}
