{ config, ... }:

let
  inherit (config.services.cyberspace) ports;
  nginxExporterPort = ports.exporters.nginx;
  nginxStatusPort = ports.monitoring.nginxStatus;  # Changed from 8080 to avoid conflict with Open WebUI
in
{
  # Enable nginx stub_status for metrics collection
  services.nginx.statusPage = true;

  # Enable nginx_exporter
  services.prometheus.exporters.nginx = {
    enable = true;
    port = nginxExporterPort;
    listenAddress = "127.0.0.1";

    # Point to nginx stub_status endpoint
    scrapeUri = "http://localhost:${toString nginxStatusPort}/nginx_status";
  };

  # Configure nginx to serve stub_status on localhost:9080
  services.nginx.virtualHosts."localhost" = {
    listen = [{
      addr = "127.0.0.1";
      port = nginxStatusPort;
    }];

    locations."/nginx_status" = {
      extraConfig = ''
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
      '';
    };
  };

  # Register in metrics registry
  services.cyberspace.metrics.registeredMetrics.nginx-exporter = {
    job_name = "nginx";
    description = "Nginx web server metrics (requests, connections, status codes)";
    scrape_interval = "15s";
    targets = [ "localhost:${toString nginxExporterPort}" ];
    labels = {
      instance = "cyberspace";
      exporter = "nginx";
      service = "nginx";
    };
    enabled = true;
    tags = [ "system" "webserver" "performance" ];
  };
}
