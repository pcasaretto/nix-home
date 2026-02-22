{ config, pkgs, ... }:

let
  inherit (config.services.cyberspace) ports;
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

  # Fetch Nextcloud dashboard
  nextcloudDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/11033/revisions/1/download";
    hash = "sha256-Ju7xO4t1zmK0LOQMizJODqEvrYv9HY0wRcOiUzld6pg=";
  };

  # Fetch Home Assistant System dashboard
  homeAssistantDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/15832/revisions/1/download";
    hash = "sha256-SQzTMMwqcZPp21PmD1chDijYqwy1eYCmZYTnPboW9IA=";
  };

  # Fetch Loki dashboards
  lokiDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/13186/revisions/latest/download";
    hash = "sha256-pe6LFUzy6OB3hCsALCmhdxX8MH92IW9HgXquid0IHYY=";
  };

  loggingDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/18042/revisions/latest/download";
    hash = "sha256-jYVkvvCqn/wW/DAcOo2zzeIMKW4RjOuaz0zWKr/VnEo=";
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
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString ports.monitoring.loki}";
          jsonData = {
            maxLines = 1000;
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
    "L+ /var/lib/grafana/dashboards/sonarr-dashboard.json - - - - ${sonarrDashboard}"
    "L+ /var/lib/grafana/dashboards/radarr-dashboard.json - - - - ${radarrDashboard}"
    "L+ /var/lib/grafana/dashboards/lidarr-dashboard.json - - - - ${lidarrDashboard}"
    "L+ /var/lib/grafana/dashboards/prowlarr-dashboard.json - - - - ${prowlarrDashboard}"
    "L+ /var/lib/grafana/dashboards/transmission-dashboard.json - - - - ${transmissionDashboard}"

    "L+ /var/lib/grafana/dashboards/nextcloud-dashboard.json - - - - ${nextcloudDashboard}"
    "L+ /var/lib/grafana/dashboards/home-assistant-dashboard.json - - - - ${homeAssistantDashboard}"
    "L+ /var/lib/grafana/dashboards/loki-dashboard.json - - - - ${lokiDashboard}"
    "L+ /var/lib/grafana/dashboards/logging-dashboard.json - - - - ${loggingDashboard}"
  ];

  # Ensure Grafana starts after Prometheus and Loki
  systemd.services.grafana = {
    after = [ "prometheus.service" "loki.service" "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
