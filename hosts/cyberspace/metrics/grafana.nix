{ config, lib, pkgs, ... }:

let
  prometheusConfig = config.services.prometheus;
  grafanaPort = 3000;

  # Fetch Node Exporter Full dashboard from Grafana.com
  nodeExporterDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
    hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
  };

  # Fetch Nginx Exporter dashboard from Grafana.com
  nginxExporterDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/12708/revisions/1/download";
    hash = "sha256-T1HqWbwt+i/We+Y2B7hcl3CijGxZF5QI38aPcXjk9y0=";
  };
in
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        # Listen on localhost only - nginx proxies
        protocol = "http";
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "cyberspace";
        root_url = "%(protocol)s://%(domain)s/grafana/";
        serve_from_sub_path = true;
      };

      # Security settings
      security = {
        admin_user = "admin";
        # Use sops-nix for password management
        admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
        disable_gravatar = true;
      };

      # Analytics
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };

      # Allow anonymous viewing (since it's Tailscale-only)
      # Read-only access for convenience on trusted network
      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";  # Read-only for anonymous
      };
    };

    # Declarative datasource configuration
    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://${prometheusConfig.listenAddress}:${toString prometheusConfig.port}/prometheus";
          isDefault = true;
          jsonData = {
            timeInterval = "15s";
            httpMethod = "POST";
          };
        }
      ];

      # Provision default dashboards
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "default";
            orgId = 1;
            folder = "";
            type = "file";
            disableDeletion = false;
            updateIntervalSeconds = 10;
            allowUiUpdates = true;
            options.path = "/var/lib/grafana/dashboards";
          }
        ];
      };
    };
  };

  # Create dashboard directory and provision dashboards
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "L+ /var/lib/grafana/dashboards/node-exporter-full.json - - - - ${nodeExporterDashboard}"
    "L+ /var/lib/grafana/dashboards/nginx-exporter-full.json - - - - ${nginxExporterDashboard}"
  ];

  # Ensure Grafana starts after Prometheus
  systemd.services.grafana = {
    after = [ "prometheus.service" "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
