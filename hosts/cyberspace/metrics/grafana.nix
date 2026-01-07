{ config, lib, pkgs, ... }:

let
  ports = config.services.cyberspace.ports;
  prometheusConfig = config.services.prometheus;
  grafanaPort = ports.frontend.grafana;

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

  # Fetch *arr service dashboards
  sonarrDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/12530/revisions/1/download";
    hash = "sha256-wkrKTf4Bw/6hWZrnUupHPSGQ4FMh+xY5H08/6EXGhUk=";
  };

  radarrDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/12896/revisions/1/download";
    hash = "sha256-MGLFgQhMoCB6hD/uci+NfN6q4tssWbsfqINpQsrlF7s=";
  };

  lidarrDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/12569/revisions/1/download";
    hash = "sha256-bt/o3OPi8GPjsaxJtf2MDvDS8cDZL7TA8MPjj4mOK4A=";
  };

  prowlarrDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/15387/revisions/1/download";
    hash = "sha256-dj+kPtBbTuvLQfscHhwSR0vKEOCOZw57CxgrMawmmMc=";
  };

  transmissionDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/10428/revisions/1/download";
    hash = "sha256-VxfwdVZeNFzlLGMxibMSXVGQ8cmuZ21u5mNvwKpHQb4=";
  };

  # Fetch ntfy notification service dashboard
  # Note: This dashboard requires both Prometheus (for metrics) and Loki (for logs)
  # Only Prometheus panels will work until Loki is configured
  ntfyDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/21873/revisions/1/download";
    hash = "sha256-a6IdUbZaqRj3Mboc0aFvddZjO5+u7K1YgYAVbJr3OoI=";
  };
in
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        # Listen on localhost only - Caddy proxies
        protocol = "http";
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "grafana.${config.services.cyberspace.domain}";
        root_url = "https://grafana.${config.services.cyberspace.domain}/";
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
          # Updated: Prometheus no longer has /prometheus prefix
          url = "http://${prometheusConfig.listenAddress}:${toString prometheusConfig.port}";
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

      # Configure alerting with ntfy webhook
      alerting = {
        contactPoints.settings = {
          apiVersion = 1;
          contactPoints = [
            {
              orgId = 1;
              name = "ntfy-alerts";
              receivers = [
                {
                  uid = "ntfy-webhook";
                  type = "webhook";
                  disableResolveMessage = false;
                  settings = {
                    url = "https://ntfy.${config.services.cyberspace.domain}/grafana";
                    httpMethod = "POST";
                    username = "$__file{${config.sops.secrets.ntfy-grafana-username.path}}";
                    password = "$__file{${config.sops.secrets.ntfy-grafana-password.path}}";
                    maxAlerts = "10";
                  };
                }
              ];
            }
          ];
        };

        policies.settings = {
          apiVersion = 1;
          policies = [
            {
              orgId = 1;
              receiver = "ntfy-alerts";
              group_by = [ "alertname" "grafana_folder" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            }
          ];
        };
      };
    };
  };

  # Create dashboard directory and provision dashboards
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "L+ /var/lib/grafana/dashboards/node-exporter-full.json - - - - ${nodeExporterDashboard}"
    "L+ /var/lib/grafana/dashboards/nginx-exporter-full.json - - - - ${nginxExporterDashboard}"
    "L+ /var/lib/grafana/dashboards/sonarr-dashboard.json - - - - ${sonarrDashboard}"
    "L+ /var/lib/grafana/dashboards/radarr-dashboard.json - - - - ${radarrDashboard}"
    "L+ /var/lib/grafana/dashboards/lidarr-dashboard.json - - - - ${lidarrDashboard}"
    "L+ /var/lib/grafana/dashboards/prowlarr-dashboard.json - - - - ${prowlarrDashboard}"
    "L+ /var/lib/grafana/dashboards/transmission-dashboard.json - - - - ${transmissionDashboard}"
    "L+ /var/lib/grafana/dashboards/ntfy-dashboard.json - - - - ${ntfyDashboard}"
  ];

  # Ensure Grafana starts after Prometheus
  systemd.services.grafana = {
    after = [ "prometheus.service" "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
